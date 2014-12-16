require 'pty'
require 'io/wait'

require 'pty'
require 'io/wait'
require 'ptools'
require 'tmpdir'
require 'exercise_marker_handler'

class PtyRunner
  IMAGE_POSTFIX = "_image"

  def run(repo)
    image_name = repo.gsub(/.*\/(.*)\.git/, '\1') + IMAGE_POSTFIX
    Dir.mktmpdir do |dir|
      clone_path = "#{dir}/exercise"

      git_result = git_clone(repo, clone_path)
      unless check_exit_status(git_result)
        puts "Git clone returns with error #{git_result}"
        exit(false)
      end
      puts "Repository cloned successfully!"

      docker_build_result = docker_build(image_name, clone_path)
      unless check_exit_status(docker_build_result)
        puts "Docker build returns with error #{docker_build_result}"
        exit(false)
      end
      puts "Docker image was built successfully!"

      test_with_solution_result = run_test_with_solution(clone_path, image_name)
      test_without_solution_result = run_test_without_solution(clone_path, image_name)

      puts "Tests completed with results: #{test_with_solution_result}, #{test_without_solution_result}"
    end
  end

  def run_test_without_solution(repo_path, image_name)
    result = nil
    copy_repo(repo_path) do |dir|
      ExerciseMarkerHandler.prepare(dir)
      result = run_tests(dir, :test, image_name)
    end

    result
  end

  def run_test_with_solution(repo_path, image_name)
    result = nil
    copy_repo(repo_path) do |dir|
      result = run_tests(dir, :test, image_name)
    end

    result
  end

  def copy_repo(repo_path, &block)
    Dir.mktmpdir do |dir|
      FileUtils.cp_r("#{repo_path}/.", dir)
      block.call(dir)
    end
  end

  def run_tests(repo_path, target, image_name)
    runner_volume = File.expand_path('./templates')

    status = nil
    PTY::spawn('docker',
               'run',
               "--volume=#{runner_volume}:/runner",
               "--volume=#{repo_path}/exercise:/usr/src/app",
               image_name,
               '/bin/bash',
               "/runner/#{target}.sh") do |r, w, pid|

      while r.wait do
        buf = r.read_nonblock(4096)
        print buf
      end

        _, status = Process.wait2(pid)
      end

      status.exitstatus
  end

  def git_clone(repo, clone_path)
    status = nil
    PTY::spawn('git', 'clone', repo, clone_path) do |r, w, pid|
      f = File.new("git_stdout.log", "wb")
      while r.wait do
        buf = r.read_nonblock(4096)
        print buf
        f.write(buf)
      end

      f.close
      _, status = Process.wait2(pid)
    end

    status.exitstatus
  end

  def docker_build(image_name, build_path)
    status = nil
    PTY::spawn('docker', 'build', "--tag=#{image_name}", build_path) do |r, w, pid|
      while r.wait do
        buf = r.read_nonblock(4096)
        print buf
      end

      _, status = Process.wait2(pid)
    end

    status.exitstatus
  end

  def check_exit_status(exitstatus)
    exitstatus == 0
  end
end
