require 'rake'
require 'ptools'

class ExerciseMarkerHandler
  def self.prepare(dir)
    FileUtils.cd(dir) do
      all_files = Rake::FileList.new("exercise/**/*")
      files = Rake::FileList.new("exercise/**/*") do |f|
        ignorefile = File.join(dir, 'Ignorefile')
        if File.exist? ignorefile
          ignorelist = File.read(ignorefile).split("\n").reject(&:empty?).map(&:chomp)
          ignorelist.each {|pattern| f.exclude(pattern)}
        end
      end

      (all_files - files).each {|file| FileUtils.rm_rf(file)} # TODO: see doc about security

      files.each do |entry|
        if File.file?(entry) && !File.binary?(entry)
          content = File.read(entry)
          processed = process(content)
          File.open(entry, 'w') { |file| file << processed }
        end
      end
    end
  end

  def self.process(content)
    rewrite_regexp = /(?<begin>[^\n]*?BEGIN[^\n]*?\n)(.+?)(?<end>\n[^\n]+?END)/m
    if content.match(rewrite_regexp)
      content.gsub(rewrite_regexp, '\k<begin>\k<end>')
    else
      content
    end
  end
end
