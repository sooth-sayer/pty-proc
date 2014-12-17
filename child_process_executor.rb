require 'childprocess'
require 'io/wait'

ChildProcess.posix_spawn = true

class ChildProcessExecutor
  def self.start(*args, output_stream)
    r,w = IO.pipe

    process = ChildProcess.build(*args)
    process.io.stdout = process.io.stderr = w

    process.start
    w.close

    while r.wait do
      output = r.read_nonblock(4096)
      print output
      output_stream.write(output)
    end

    r.close
    process.wait
    process.exit_code
  end
end
