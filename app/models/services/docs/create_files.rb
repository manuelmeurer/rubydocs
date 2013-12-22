require 'rdoc'
require 'sdoc'

module Services
  module Docs
    class CreateFiles < Services::Base
      FilesExistsError = Class.new(Error)
      CreatingInProgressError = Class.new(Error)

      def call(doc)
        guard_creating doc do
          git = Git.open(doc.project.local_path)
          git.checkout doc.tag
          rdoc = RDoc::RDoc.new
          args = [
            '--format=sdoc',
            '--line-numbers',
            "--title=#{doc.project.name} #{doc.tag}",
            "--output=#{doc.local_path}",
            '--exclude=test',
            '--exclude=example',
            '--exclude=bin',
            doc.project.local_path.to_s
          ]
          %w(README README.md README.markdown README.mdown README.txt).each do |readme|
            if File.exist?(doc.project.local_path.join(readme))
              args.unshift("--main=#{readme}")
              break
            end
          end
          rdoc.document args
        end
        doc
      end

      private

      def guard_creating(doc, &block)
        creating_file = doc.project.local_path.join('.rubydocs-creating-files')
        raise CreatingInProgressError, "A doc for project #{doc.project.name} is already being created." if File.exist?(creating_file)
        raise FilesExistsError, "Files for doc #{doc.name} already exist." if File.exist?(doc.local_path) && Dir[File.join(doc.local_path, '*')].present?
        FileUtils.mkdir_p doc.project.local_path
        FileUtils.touch creating_file

        block.call

        File.delete creating_file
      end
    end
  end
end