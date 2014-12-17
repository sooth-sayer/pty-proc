require 'childprocess'
require 'io/wait'
require 'ptools'
require 'tmpdir'
require 'exercise_marker_handler'

ChildProcess.posix_spawn = true

class ChildProcessRunner
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

    r, w = IO.pipe
    process = ChildProcess.build('docker',
               'run',
               "--volume=#{runner_volume}:/runner",
               "--volume=#{repo_path}/exercise:/usr/src/app",
               image_name,
               '/bin/bash',
               "/runner/#{target}.sh")

    process.io.stdout = process.io.stderr = w
    process.start
    w.close

    while r.wait do
      buf = r.read_nonblock(4096)
      print buf
    end

    process.wait
    process.exit_code
  end

  def git_clone(repo, clone_path)
    File.open("git_stdout.log", "w") do |file|
      r, w = IO.pipe
      process = ChildProcess.build('git', 'clone', '--progress', repo, clone_path)
      process.io.stderr = process.io.stdout = w
      process.start
      w.close

      while r.wait do
        buf = r.read_nonblock(4096)
        print buf
        file.write(buf)
      end

      process.wait
      process.exit_code
    end
  end

  def docker_build(image_name, build_path)
    r, w = IO.pipe
    process = ChildProcess.build('docker', 'build', "--tag=#{image_name}", build_path)
    process.io.stderr = process.io.stdout = w
    process.start
    w.close

    while r.wait do
      buf = r.read_nonblock(4096)
      print buf
    end

    process.wait
    process.exit_code
  end

  def check_exit_status(exitstatus)
    exitstatus == 0
  end
end
