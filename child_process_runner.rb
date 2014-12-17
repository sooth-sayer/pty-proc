require 'childprocess'
require 'io/wait'
require 'ptools'
require 'tmpdir'
require 'exercise_marker_handler'
require 'child_process_executor'
require 'stringio'

ChildProcess.posix_spawn = true

class ChildProcessRunner
  IMAGE_POSTFIX = "_image"

  attr_reader :log

  def initialize
    @log = StringIO.new
  end

  def run(repo)
    image_name = repo.gsub(/.*\/(.*)\.git/, '\1') + IMAGE_POSTFIX
    Dir.mktmpdir do |dir|
      success = true
      clone_path = "#{dir}/exercise"

      success = git_clone(repo, clone_path)
      if success
        puts 'Repository cloned successfully!'
      else
        puts 'Git clone failed'
      end

      success &&= docker_build(image_name, clone_path)
      if success
        puts 'Docker image was built successfully!'
      else
        puts 'Docker build failed'
      end

      if success
        test_with_solution_result = run_test_with_solution(clone_path, image_name)
        test_without_solution_result = run_test_without_solution(clone_path, image_name)

        puts "Tests completed with results: #{test_with_solution_result}, #{test_without_solution_result}"
      end
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

    ChildProcessExecutor.start('docker',
                               'run',
                               "--volume=#{runner_volume}:/runner",
                               "--volume=#{repo_path}/exercise:/usr/src/app",
                               image_name,
                               '/bin/bash',
                               "/runner/#{target}.sh", log)
  end

  def git_clone(repo, clone_path)
    ChildProcessExecutor.start('git', 'clone', '--progress', repo, clone_path, log) do |process|
      process.environment['GIT_SSH'] = './templates/git_ssh.sh'
    end
  end

  def docker_build(image_name, build_path)
    ChildProcessExecutor.start('docker', 'build', "--tag=#{image_name}", build_path, log)
  end
end
