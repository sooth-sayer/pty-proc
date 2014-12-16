require 'sidekiq'
require 'pty'
require 'io/wait'

require 'pty'
require 'io/wait'
require 'pty_runner'

class HardWorker
  include Sidekiq::Worker

  def perform(repo)
    pty_runner = PtyRunner.new
    pty_runner.run(repo)
  end
end
