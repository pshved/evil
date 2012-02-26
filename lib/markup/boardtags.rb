# coding: utf-8
require 'treetop'
require 'erb'

# The actual value does not matter now, it will be reset at filter() call
# NOTE that this is a global variable, so we can't parse concurrently...
$c = nil

# Tag conversions.  Use $c.sign hash to add "marks" to the posts.
TagConversions = [
  ['b',        proc {|inner| "<b>#{inner}</b>"}],
  ['i',        proc {|inner| "<i>#{inner}</i>"}],
  ['u',        proc {|inner| "<u>#{inner}</u>"}],
  ['h',        proc {|inner| %Q(<span class="h">#{inner}</span>)}],
  ['s',        proc {|inner| %Q(<span class="s">#{inner}</span>)}],
  ['red',      proc {|inner| %Q(<span style="color:red">#{inner}</span>)}],
  ['color',    proc {|inner,color| %Q(<span style="color:#{color}">#{inner}</span>)}],
  ['url',      proc {|inner,url| $c.sign[:url] = true;  %Q(<a href="#{url}" target=_blank>#{inner}</a>)}],
  ['pic',      proc {|inner| $c.sign[:pic] = true;  %Q(<img class="imgtag" src="#{inner}"/>)}],
  ['hr',       proc {|| %Q(<hr/>)}],
  ['tab',      proc {|| %Q(&nbsp;)*9}],
  ['q',        proc {|inner| %Q(<blockquote><span class="inquote">[q]</span><b>Quote:</b><br/>#{inner}<span class="inquote">[/q]</span></blockquote>)}],
  ['center',   proc {|inner| %Q(<center>#{inner}</center>)}],
  # [pre] is handled in the parser
  ['strike',   proc {|inner| %Q(<strike>#{inner}</strike>)}],
  ['sub',      proc {|inner| %Q(<sub>#{inner}</sub>)}],
  ['sup',      proc {|inner| %Q(<sup>#{inner}</sup>)}],
  # [tex] is handled in the parser
  ['tub',      proc {|inner| $c.sign[:vid] = true;  %Q(<iframe class="youtube-player" type="text/html" width="640" height="390" src="http://www.youtube.com/embed/#{inner}?iv_load_policy=3&rel=0&fs=1" frameborder="0"></iframe>)}],
  ['spoiler',  proc{|inner| %Q(<span style="spoiler">#{inner}</span>)}],
]

def wrap(tag,wtf,close_tag = nil); %Q(wrap('[#{tag}]', '[/#{close_tag ? close_tag : tag}]', #{wtf});); end
def _wrap(open,wtf,close); %Q(wrap('#{open}', '#{close}', #{wtf});); end

dbr = {:name => ''}
BUTTON_REGISTRY = {
  'b' => dbr.merge({:accesskey => 'l', :style => 'width: 35px', :title => 'bold', :onclick => wrap('b',1)}),
  'i' => dbr.merge({:accesskey => 'r', :style => 'width: 35px', :title => 'italiq', :onclick => wrap('i',1)}),
  'b' => dbr.merge({:accesskey => 'b', :style => "width: 30px", :title => "жирный текст: [b]текст[/b] (alt+b)", :onclick => wrap('b',1)}),
  'i' => dbr.merge({:accesskey => "i", :style => "width: 30px", :title => "курсивный текст: [i]текст[/i] (alt+i)", :onclick => wrap('i',1)}),
  'u' => dbr.merge({:accesskey => "u", :style => "width: 30px", :title => "подчеркнутый текст: [u]текст[/u] (alt+u)", :onclick => wrap('u',1)}),
  'q' => dbr.merge({:accesskey => "q", :style => "width: 30px", :title => "цитата: [q]текст[/q] (alt+q)", :onclick => wrap('q',0)}),
  'pic' => dbr.merge({:accesskey => "p", :style => "width: 40px", :title => "изображение: [pic]http://ссылка[/pic] (alt+p)", :onclick => wrap('pic',0)}),
  'url' => dbr.merge({:accesskey => "w", :style => "width: 40px", :title => "ссылка: [url=http://ссылка]название[/url] (alt+w)", :onclick => _wrap('[url=',1,']ссылка[/url]')}),
  'h' => dbr.merge({:accesskey => "h", :style => "width: 30px", :title => "заголовок: [h]текст[/h] (alt+h)", :onclick => wrap('h',1)}),
  's' => dbr.merge({:accesskey => "s", :style => "width: 30px", :title => "мелкий текст: [s]текст[/s] (alt+s)", :onclick => wrap('s',1)}),
  'sup' => dbr.merge({:accesskey => "6", :style => "width: 40px", :title => "верхний индекс: [sup]текст[/sup] (alt+6)", :onclick => wrap('sup',0)}),
  'sub' => dbr.merge({:accesskey => "-", :style => "width: 40px", :title => "нижний индекс: [sub]текст[/sub] (alt+-)", :onclick => wrap('sub',0)}),
  'strike' => dbr.merge({:accesskey => "=", :style => "width: 55px", :title => "перечеркнутый текст: [strike]текст[/strike] (alt+=)", :onclick => wrap('strike',1)}),
  'color' => dbr.merge({:accesskey => "3", :style => "width: 55px", :title => "цветной текст: [color=#цвет]текст[/color] (alt+3)", :onclick => _wrap('[color=#00FF00]',1,'[/color]')}),
  'red' => dbr.merge({:accesskey => "r", :style => "width: 40px", :title => "красный текст: [red]текст[/red] (alt+r)", :onclick => wrap('red',1)}),
  'pre' => dbr.merge({:accesskey => "f", :style => "width: 40px", :title => "преформатированный текст: [pre]текст[/pre] (alt+f)", :onclick => wrap('pre',0)}),
  'center' => dbr.merge({:accesskey => "c", :style => "width: 60px", :title => "центрированный текст: [center]текст[/center] (alt+c)", :onclick => wrap('center',0)}),
  'tex' => dbr.merge({:accesskey => "t", :style => "width: 40px", :title => "TEX-формула: [tex]текст[/tex] (alt+t)", :onclick => wrap('tex',0)}),
  'tub' => dbr.merge({:accesskey => "y", :style => "width: 40px", :title => "YouTube-видео: [tub]идентификатор видео[/tub] (alt+y)", :onclick => wrap('tub',0)}),
  'spoiler' => dbr.merge({:accesskey => ".", :style => "width: 65px", :title => "спойлер: [spoiler]текст[/spoiler] (alt+.)", :onclick => wrap('spoiler',1)}),
  'hr' => dbr.merge({:accesskey => "l", :style => "width: 35px", :title => "горизонтальная линия: [hr] (alt+l)", :onclick => wrap('hr',1)}),
  'smile' => dbr.merge({:name => 'smile', :accesskey => "0", :style => "width: 55px", :title => "таблица смайлов (alt+0)", :onclick => wrap('smile',1)}),
}

# NOTE: the lambdas created in TagConversions will be evaluated in a special context, which is supplied by the caller, and is read by it as well.

# TODO : move this to app.config
def make_smiley(smn)
  "/pic/#{smn}"
end

Replacements = [
  # Replace newlines with HTML tag (but save the line breaks for a nicer view)
  ["\r\n",      "<br/>\n"                       ],
  # the next matches only after the previous one is exhausted
  ["\n",        "<br/>\n"                       ],
  # indent with 9 non-breaking spaces
  ["^\t",       "&nbsp;" * 9                    ],
  # The rest is smileys
  [":))",       make_smiley("bigsmile.gif")     ],
  [":)",        make_smiley("smile.gif")        ],
  [":(",        make_smiley("frown.gif")        ],
  [";)",        make_smiley("wink.gif")         ],
  [":!!",       make_smiley("lol.gif")          ],
  [":\\",       make_smiley("smirk.gif")        ],
  [":o",        make_smiley("redface.gif")      ],
  [":MAD",      make_smiley("mad.gif")          ],
  [":STOP",     make_smiley("stop.gif")         ],
  [":APPL",     make_smiley("appl.gif")         ],
  [":BAN",      make_smiley("ban.gif")          ],
  [":BEE",      make_smiley("bee.gif")          ],
  [":BIS",      make_smiley("bis.gif")          ],
  [":ZLOBA",    make_smiley("blya.gif")         ],
  [":BORED",    make_smiley("bored.gif")        ],
  [":BOTAT",    make_smiley("botat.gif")        ],
  [":COMP",     make_smiley("comp.gif")         ],
  [":CRAZY",    make_smiley("crazy.gif")        ],
  [":DEVIL",    make_smiley("devil.gif")        ],
  [":DOWN",     make_smiley("down.gif")         ],
  [":FIGA",     make_smiley("figa.gif")         ],
  [":GIT",      make_smiley("git.gif")          ],
  [":GYGY",     make_smiley("gy.gif")           ],
  [":HEH",      make_smiley("heh.gif")          ],
  [":CIQ",      make_smiley("iq.gif")           ],
  [":KURIT",    make_smiley("kos.gif")          ],
  [":LAM",      make_smiley("lam.gif")          ],
  [":MNC",      make_smiley("mnc.gif")          ],
  [":NO",       make_smiley("no.gif")           ],
  [":SMOKE",    make_smiley("smoke.gif")        ],
  [":SORRY",    make_smiley("sorry.gif")        ],
  [":SUPER",    make_smiley("super.gif")        ],
  [":UP",       make_smiley("up.gif")           ],
  [":YES2",     make_smiley("yes2.gif")         ],
  [":YES",      make_smiley("yes.gif")          ],
  [":BASH",     make_smiley("bash.gif")         ],
  [":CLAPPY",   make_smiley("clappy.gif")       ],
  [":EWW",      make_smiley("eww.gif")          ],
  [":ROTFL",    make_smiley("roflol.gif")       ],
  [":SPOTMAN",  make_smiley("spotman.gif")      ],
  [":WAVE",     make_smiley("wave.gif")         ],
  [":COWARD",   make_smiley("coward.gif")       ],
  [":DRAZNIT",  make_smiley("draznit.gif")      ],
  [":ROLLEYES", make_smiley("rolleyes.gif")     ],
  [":PLOHO",    make_smiley("blevalyanaeto.gif")],
  [":}",        make_smiley("icqbig.gif")       ],
]

only, both = TagConversions.partition{|tc| tc[1].arity == 0}

TagOpens = TagConversions.map{|tc| tc[0]}
TagCloses = both.map{|tc| tc[0]}
TagOnly = only.map{|tc| "[#{tc[0]}"}

# Convenience module for grammar
module ProxyNode
  def to_body
    elements.nil?? text_value : elements[0].to_body
  end
end

class DefaultParseContext
  attr_accessor :sign
  def initialize
    @sign = {}
  end
  def get_binding
    return binding
  end
end

module RegexpConvertNode
  def to_body
    t = ERB::Util::html_escape(text_value)
    # Find each conversion until it's exhausted
    TagConversions.each do |tcd|
      tag, conv = tcd
      # Match prefix greedily, so that we only get the last matching tag.  Match contents lazily, so that we do not span across the potential tag borders.
      # Note the regexp multiline mode, as we want the formatted text to span across line breaks.
      # Note also the unicode in messages
      # We use html_safe to make Rails not html-escape strings on concatenation.
      # Check how many arguments there are in the conv, and reason about tag format
      case conv.arity
      when 0
        # Regexp is (...)[tag](...)
        rx = /^(.*)\[#{tag}\](.*)$/mu
        while md = t.match(rx)
          t = md[1] + conv[].html_safe + md[2]
        end
      when 1
        # Regexp is (...)[tag](...)[/tag](...)
        rx = /^(.*)\[#{tag}\](.*?)\[\/#{tag}\](.*)$/mu
        while md = t.match(rx)
          t = md[1] + conv[md[2]].html_safe + md[3]
        end
      when 2
        # Regexp is (...)[tag=(...)](...)[/tag](...)
        rx = /^(.*)\[#{tag}=([^\]]*)\](.*?)\[\/#{tag}\](.*)$/mu
        while md = t.match(rx)
          t = md[1] + conv[md[3],md[2]].html_safe + md[4]
        end
      end
    end
    # Now apply the other replacements
    Replacements.each do |rcd|
      replace, with = rcd
      t.gsub!(replace,with)
    end
    # Now convert URLs to links
    result = ''
    to_convert = t
    debugger
    while not to_convert.empty?
      # The regexp should detect URLs with ports, and do not include the trailing punctuation in 'http://ya.ru.' or 'http://ya.ru/url/.'
      # Match:  protocol           // path                         country     ( port(if any), the rest, last should be an alnum) if any
      if md = (/(http|https|ftp):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}((:[0-9]{1,5})?[a-z0-9_\-\.%\/]*[a-z0-9_\-\/])?/im.match(to_convert))
        result << md.pre_match << %Q(<a href="#{md[0]}">#{md[0].html_safe}</a>)
        to_convert = md.post_match
      else
        # No more URLs left, returning
        result += to_convert
        to_convert = ''
      end
    end
    t = result
    t
  end
end

Treetop.load 'lib/markup/tags.tt'

# Monkey-patch all nodes, so that they respond to our semantic methods
module Treetop
  module Runtime
    class SyntaxNode
      def to_body
        text_value
      end
    end
  end
end


module BoardtagsFilter
  @@parser = BoardTagsParser.new

  def self.filter(text, method = :to_body, context = nil)
    # If the context is unspecified, create the default
    context ||= DefaultParseContext.new
    # Update parsing context
    $c = context
    # Re-parse grammar
    #p @@parser.parse(text)
    tree = @@parser.parse text
    if tree
      tree.send method
    else
      puts @@parser.failure_reason
      nil
    end
  end

end


