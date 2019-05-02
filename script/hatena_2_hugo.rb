#!/usr/bin/env ruby

require 'date'
require 'mustache'
require 'stringex'
require 'cgi'
require 'fileutils'

export     = File.open(ARGV[0])
target_dir = ARGV[1]

class Post < Mustache
  self.template = <<-MARKDOWN

---
title: "{{title}}"
date: {{date}}
category : [{{completed_cateogory}}]
canonicalurl: http://yut.hatenablog.com/entry/{{path_of_basename}}
---

## [{{completed_cateogory}}] : {{title}}

{{{formatted_body}}}
MARKDOWN

  attr_accessor :author, :title, :category, :comments, :status, :body, :basename

  def initialize
    @body = []
  end

  def date=(date)
    case date
    when String
      @date = DateTime.strptime(date, "%m/%d/%Y %H:%M:%S")
    else
      @date = date
    end
  end

  def date
    @date
  end

  def formatted_date
    @date.strftime("%Y-%m-%d %H:%M")
  end

  def comments=(comments)
    @comments = comments == "1" ? true : false
  end

  def formatted_body
    CGI.unescapeHTML(body.join).
      gsub("<!--more-->", "\n\n<!-- more -->\n\n").
      gsub(/^\t+/, '').
      gsub(/^    /, '').
      gsub('"hatena-asin-detail"', '"amazlet-box"').
      gsub(/"code lang-(.*?)"/, '"hljs \1"')
  end

  def file_name
    "#{date.strftime("%Y%m%d%H%M")}.md"
  end

  def completed_cateogory
      @category || 'etc'
  end

  def path_of_old_url
    @date.strftime("%Y/%m/%d")
  end

  def path_of_basename
    @basename
  end

end

posts = [Post.new]

KEYWORDS = /(AUTHOR|TITLE|STATUS|COMMENTS|CATEGORY|DATE|BASENAME): (.*)/

def attr_and_value(line)
  line =~ KEYWORDS
  ["#{$1.downcase}=", $2]
end

puts " # Reading from data '#{ARGV[0]}' ..."

puts " # Generating Markdown ..."

comment_section = false

export.each do |line|
  if line.strip == "--------"
    posts << Post.new
    print '.'
    comment_section = false
    next
  end

  next if comment_section

  case line.strip
  when KEYWORDS
    posts.last.send(*attr_and_value(line))
  when /BODY/
    next
  when "-----"
    next
  when /COMMENT:/
    comment_section = true
    next
  when /^[A-Z][A-Z ]+:/
    next  # ignore other tags
  else
    posts.last.body << line
  end
end

posts_by_date = {}
posts.each do |post|
    next unless post.date
    key = post.date.strftime('%Y/%m/%d')
    if posts_by_date.has_key?(key)
        posts_by_date[key].body << "<h2>#{post.title}</h2>"
        posts_by_date[key].body << post.formatted_body
        next
    end

    posts_by_date[key] = post
end

puts
puts " # Writing files to #{target_dir} ..."
`mkdir -p #{target_dir}`
`cd #{target_dir} && rm -rf _posts && mkdir _posts`

ok, fails = 0, 0

posts_by_date.keys.each do |k|
  post = posts_by_date[k]
  begin
    File.open(File.join(target_dir, "_posts", post.file_name), "w+") { |f| f.puts post.render }
    FileUtils.touch(File.join(target_dir, "_posts", post.file_name), :mtime => post.date.to_time)
    puts " -> #{post.file_name}"
    ok += 1
  rescue => e
    puts " # Could not write file for '#{post.title}'"
    puts e
    fails += 1
  end
end

puts
puts " # All done! (#{ok}/#{fails})"
