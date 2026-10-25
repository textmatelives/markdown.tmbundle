#!/usr/bin/env ruby -wEutf-8
# Run with: ruby Tests/heading_level_test.rb
#
# Runs the command text shipped in the two heading-level tmCommands with
# TM_CURRENT_LINE set, the way TextMate does, and checks the output. The
# expectations were taken from the original python commands (issue #6).
require 'rexml/document'
require 'tempfile'

$failures = 0

def command_text(name)
	plist = REXML::Document.new(File.read(File.expand_path("../Commands/#{name}.tmCommand", __dir__)))
	plist.elements.each('//dict/key') { |key| return key.next_element.text if key.text == 'command' }
	raise "no command key in #{name}"
end

def run(name, line)
	text = command_text(name)
	raise "#{name} is not a ruby command" unless text.start_with?("#!/usr/bin/env ruby")
	Tempfile.create(['heading', '.rb']) do |f|
		f.write(text)
		f.flush
		IO.popen({ 'TM_CURRENT_LINE' => line, 'LC_ALL' => 'C', 'LANG' => nil }, ['ruby', f.path], &:read)
	end
end

def check(name, line, want)
	got = run(name, line)
	return if got == want
	puts "FAIL #{name} #{line.inspect}: want #{want.inspect}, got #{got.inspect}"
	$failures += 1
end

INCREASE = 'Increase Heading Level'
DECREASE = 'Decrease Heading Level'

check INCREASE, "# Foo", "## Foo"
check INCREASE, "## Foo", "### Foo"
check INCREASE, "##### Foo", "###### Foo"
check INCREASE, "###### Foo", "###### Foo"             # already level 6: unchanged
check INCREASE, "Foo", "Foo"                    # not a heading: unchanged
check INCREASE, "#Foo", "## Foo"                 # space after the hashes normalised
check INCREASE, "##   Foo   ", "### Foo"                # surrounding space trimmed
check INCREASE, "## Foo ##", "### Foo ###"            # closing hashes follow the level
check INCREASE, "### Foo ###", "#### Foo ####"
check INCREASE, "# Foo #", "## Foo ##"
check INCREASE, "#", "#"
check INCREASE, "## ", "### "                   # empty heading keeps its trailing space (as the original did)
check INCREASE, "######## Eight", "######## Eight"         # more than six hashes: not a heading
check INCREASE, "## Foo # bar", "### Foo # bar"
check INCREASE, "## Foo \t##", "### Foo ###"
check INCREASE, "## Foo ##  ", "### Foo ##"             # trailing space after closing hashes: they count as text (as the original did)
check INCREASE, "## Café — déjà vu ##", "### Café — déjà vu ###"
check INCREASE, "## 見出し", "### 見出し"
check DECREASE, "# Foo", "# Foo"                  # already level 1: unchanged
check DECREASE, "## Foo", "# Foo"
check DECREASE, "##### Foo", "#### Foo"
check DECREASE, "###### Foo", "##### Foo"
check DECREASE, "Foo", "Foo"
check DECREASE, "#Foo", "#Foo"                   # level 1 without a space: unchanged
check DECREASE, "##   Foo   ", "# Foo"
check DECREASE, "## Foo ##", "# Foo #"
check DECREASE, "### Foo ###", "## Foo ##"
check DECREASE, "# Foo #", "# Foo #"
check DECREASE, "#", "#"
check DECREASE, "## ", "# "
check DECREASE, "######## Eight", "##### ## Eight"         # more than six hashes: the extra two become text (as the original did)
check DECREASE, "## Foo # bar", "# Foo # bar"
check DECREASE, "## Foo \t##", "# Foo #"
check DECREASE, "## Foo ##  ", "# Foo ##"
check DECREASE, "## Café — déjà vu ##", "# Café — déjà vu #"
check DECREASE, "## 見出し", "# 見出し"

if $failures.zero?
	puts 'OK'
else
	puts "#{$failures} failure(s)"
	exit 1
end
