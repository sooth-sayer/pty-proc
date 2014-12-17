require 'sidekiq'
require 'pty_runner'
require 'child_process_runner'

class HardWorker
  include Sidekiq::Worker

  def perform(repo, runner)
    runner = Object.const_get(runner).new
    runner.run(repo)
  end
end
