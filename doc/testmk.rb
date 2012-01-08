#!/usr/bin/env ruby

require './lib/markup/boardtags'

x = []
x << 'aaaa[b]nnn[/b]aaaa'
x << '[b]e[/b]'
x << '[pre]xxx[/pre]'
x << 'aaa[pre]xxx[/pre]'
x << '[pre]xxx[/pre]aa'
x << 'aa[pre]xxx[/pre]aa'
x << '[pre]
  indent
  if (a<3) { ... }
[/pre]aa'
x << 'a[b] + c[i] = [b][i]awesome[/i][/b]'
x << 'eee
multi [b]
line
bold
[/b]'

x << '[url=http://ya.ru]link to yandex[/url]'
x << '[url]BAD LINK![/url]'
x << '[url]BAD tag'
x << '[url=aaaa]BAD tag'
x << 'some [hr] zero arg tag'
x << 'some [pre]\alpha\frac{2}{4}[/pre] code'
x << 'some [tex]\alpha\frac{2}{4}[/tex] code'
x << 'bold [b]bold[/b]'

fails = 0

x.each do |s|
  puts "==========="
  puts s
  t = BoardtagsFilter.filter(s)
  fails += 1 unless t
  puts t
end

puts "Total fails: #{fails}"


