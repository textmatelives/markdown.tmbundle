#!/usr/bin/env ruby -wEutf-8
# html2markdown: turn HTML into equivalent Markdown-structured text.
#
# A Ruby port of html2text 2.35 by Aaron Swartz (C) 2004-2008, GNU GPL 3,
# which ran under python 2 and so stopped working when macOS 12.3 dropped
# that interpreter. The rules are the same: headings become `#` lines,
# emphasis `_`/`**`, links and images are numbered references listed at the
# end, lists are indented two spaces per level, `pre` is indented four, and
# paragraphs are wrapped at BODY_WIDTH. Entities are decoded by the parser
# and emitted as the characters they name; only a non-breaking space is
# turned into a plain space.
#
# Parsing is done by nokogiri's HTML SAX parser, which ships with the system
# Ruby on macOS, so the script needs nothing installed.

require 'nokogiri'

class HTML2Markdown < Nokogiri::XML::SAX::Document
	BODY_WIDTH           = 78    # 0 for no wrapping
	LINKS_EACH_PARAGRAPH = false # put the links after each paragraph instead of at the end
	SKIP_INTERNAL_LINKS  = false # drop href="#local-anchor" links

	def self.convert(html)
		document = new
		Nokogiri::HTML::SAX::Parser.new(document, 'UTF-8').parse(html)
		document.finish
	end

	def initialize
		super
		@out         = +''
		@quiet       = 0
		@p_p         = 0
		@outcount    = 0
		@start       = true
		@space       = false
		@a           = []
		@astack      = []
		@acount      = 0
		@list        = []
		@blockquote  = 0
		@pre         = false
		@last_was_nl = false
		@abbr_title  = nil
		@abbr_data   = nil
		@abbr_list   = {}
	end

	def finish
		pbr
		o('', false, :end)
		optwrap(@out)
	end

	# SAX callbacks

	def start_element(tag, attrs = [])
		handle_tag(tag, attrs.to_h, true)
	end

	def end_element(tag)
		handle_tag(tag, {}, false)
	end

	def characters(data)
		o(data.tr(" ", ' '), true)
	end

	def cdata_block(data)
		characters(data)
	end

	private

	def hn(tag)
		n = tag[1].to_i if tag.length == 2 && tag[0] == 'h'
		n if n && n.between?(1, 9)
	end

	def handle_tag(tag, attrs, start)
		if (n = hn(tag))
			p
			o('#' * n + ' ') if start
		end

		p if %w[p div].include?(tag)

		o("  \n") if tag == 'br' && start

		if tag == 'hr' && start
			p
			o('* * *')
			p
		end

		if %w[head style script].include?(tag)
			@quiet += start ? 1 : -1
		end

		@quiet = 0 if tag == 'body' # pages that never close <head>

		if tag == 'blockquote'
			if start
				p
				o('> ', false, true)
				@start = true
				@blockquote += 1
			else
				@blockquote -= 1
				p
			end
		end

		o('_')  if %w[em i u].include?(tag)
		o('**') if %w[strong b].include?(tag)
		o('`')  if tag == 'code' && !@pre

		if tag == 'abbr'
			if start
				@abbr_title = attrs['title']
				@abbr_data  = +''
			else
				@abbr_list[@abbr_data] = @abbr_title if @abbr_title
				@abbr_title = nil
				@abbr_data  = nil
			end
		end

		if tag == 'a'
			if start
				if attrs['href'] && !(SKIP_INTERNAL_LINKS && attrs['href'].start_with?('#'))
					@astack.push(attrs)
					o('[')
				else
					@astack.push(nil)
				end
			elsif (a = @astack.pop)
				a = register_link(a)
				o("][#{a['count']}]")
			end
		end

		if tag == 'img' && start && attrs['src']
			attrs = register_link(attrs.merge('href' => attrs['src']))
			o('![')
			o(attrs['alt'] || '')
			o("][#{attrs['count']}]")
		end

		p          if tag == 'dl' && start
		pbr        if tag == 'dt' && !start
		o('    ')  if tag == 'dd' && start
		pbr        if tag == 'dd' && !start

		if %w[ol ul].include?(tag)
			start ? @list.push({ name: tag, num: 0 }) : @list.pop
			p
		end

		if tag == 'li'
			if start
				pbr
				li = @list.last || { name: 'ul', num: 0 }
				o('  ' * @list.size)
				if li[:name] == 'ul'
					o('* ')
				else
					li[:num] += 1
					o("#{li[:num]}. ")
				end
				@start = true
			else
				pbr
			end
		end

		p   if %w[table tr].include?(tag) && start
		pbr if tag == 'td'

		if tag == 'pre'
			@pre = start
			p
		end
	end

	# Links are numbered in order of first use; the same href (and title)
	# reuses its number.
	def register_link(attrs)
		if (i = previous_index(attrs))
			return @a[i]
		end
		@acount += 1
		attrs['count']    = @acount
		attrs['outcount'] = @outcount
		@a << attrs
		attrs
	end

	def previous_index(attrs)
		return nil unless attrs['href']
		@a.each_with_index do |a, i|
			next unless a['href'] == attrs['href']
			if a['title'] || attrs['title']
				return i if a['title'] && attrs['title'] && a['title'] == attrs['title']
			else
				return i
			end
		end
		nil
	end

	def pbr
		@p_p = 1 if @p_p == 0
	end

	def p
		@p_p = 2
	end

	def o(data, puredata = false, force = false)
		@abbr_data << data if @abbr_data
		return if @quiet > 0

		if puredata && !@pre
			data = data.gsub(/\s+/, ' ')
			if data.start_with?(' ')
				@space = true
				data = data[1..-1]
			end
		end
		return if data.empty? && !force

		bq = '>' * @blockquote
		bq += ' ' if @blockquote > 0 && !(force && data.start_with?('>'))

		if @pre
			bq += '    '
			data = data.gsub("\n", "\n" + bq)
		end

		if @start
			@space = false
			@p_p   = 0
			@start = false
		end

		if force == :end
			@p_p = 0
			@out << "\n"
			@space = false
		end

		if @p_p > 0
			@out << ("\n" + bq) * @p_p
			@space = false
		end

		if @space
			@out << ' ' unless @last_was_nl
			@space = false
		end

		if !@a.empty? && ((@p_p == 2 && LINKS_EACH_PARAGRAPH) || force == :end)
			@out << "\n" if force == :end
			newa = []
			@a.each do |link|
				if @outcount > link['outcount']
					@out << "   [#{link['count']}]: #{link['href']}"
					@out << " (#{link['title']})" if link['title']
					@out << "\n"
				else
					newa << link
				end
			end
			@out << "\n" if @a != newa
			@a = newa
		end

		if !@abbr_list.empty? && force == :end
			@abbr_list.each { |abbr, definition| @out << "  *[#{abbr}]: #{definition}\n" }
		end

		@p_p = 0
		@out << data
		@last_was_nl = data.end_with?("\n")
		@outcount += 1
	end

	# Wrap every paragraph that does not start with a space, `-` or `*`;
	# collapse runs of blank lines to one.
	def optwrap(text)
		return text if BODY_WIDTH.zero?
		result   = +''
		newlines = 0
		text.split("\n", -1).each do |para|
			if para.empty?
				if newlines < 2
					result << "\n"
					newlines += 1
				end
			elsif ' -*'.include?(para[0])
				unless para.match?(/\A *\z/)
					result << para << "\n"
					newlines = 1
				end
			else
				wrap(para, BODY_WIDTH).each { |line| result << line << "\n" }
				result << "\n"
				newlines = 2
			end
		end
		result
	end

	# Greedy fill on whitespace, like textwrap.wrap: runs of whitespace become
	# one space, and a word longer than the width is split.
	def wrap(text, width)
		lines = []
		line  = +''
		text.split(/\s+/).reject(&:empty?).each do |word|
			while word.length > width
				if line.empty?
					lines << word[0, width]
					word = word[width..-1]
				else
					lines << line
					line = +''
				end
			end
			if line.empty?
				line = word
			elsif line.length + 1 + word.length <= width
				line << ' ' << word
			else
				lines << line
				line = word
			end
		end
		lines << line unless line.empty?
		lines
	end
end

if __FILE__ == $PROGRAM_NAME
	html = (ARGV.empty? ? STDIN.read : File.read(ARGV[0])).force_encoding(Encoding::UTF_8)
	$stdout.write(HTML2Markdown.convert(html))
end
