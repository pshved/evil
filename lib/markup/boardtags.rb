require 'treetop'
require 'erb'

# Tags
TagConversions = [
  ['b',        lambda {|inner| "<b>#{inner.html_safe}</b>".html_safe}],
  ['i',        lambda {|inner| "<i>#{inner}</i>"}],
  ['u',        lambda {|inner| "<u>#{inner}</u>"}],
  ['h',        lambda {|inner| %Q(<span class="h">#{inner}</span>)}],
  ['s',        lambda {|inner| %Q(<span class="s">#{inner}</span>)}],
  ['red',      lambda {|inner| %Q(<span style="color:red">#{inner}</span>)}],
  ['color',    lambda {|inner,color| %Q(<span style="color:#{color}">#{inner}</span>)}],
  ['url',      lambda {|inner,url| %Q(<a href="#{url}" target=_blank>#{inner}</a>)}],
  ['pic',      lambda {|inner| %Q(<img class="imgtag">#{inner}</pic>)}],
  ['hr',       lambda {|| %Q(<hr/>)}],
  ['q',        lambda {|inner| %Q(<blockquote><span class="inquote">[q]</span><b>Quote:</b><br/>#{inner}<span class="inquote">[/q]</span></blockquote>)}],
  ['center',   lambda {|inner| %Q(<center>#{inner}</center>)}],
  # [pre] is handled in the parser
  ['strike',   lambda {|inner| %Q(<strike>#{inner}</strike>)}],
  ['sub',   lambda {|inner| %Q(<sub>#{inner}</sub>)}],
  ['sup',   lambda {|inner| %Q(<sup>#{inner}</sup>)}],
  # [tex] is handled in the parser
  ['tub',   lambda {|inner| %Q(<iframe class="youtube-player" type="text/html" width="640" height="390" src="http://www.youtube.com/embed/#{inner}"?iv_load_policy=3&rel=0&fs=1" frameborder="0"></iframe>)}],
  ['spoiler', lambda{|inner| %Q(<span style="spoiler">#{inner}</span>)}],
]

def make_smiley(smn)
  "/pic/#{smn}"
end

Replacements = [
  # Replace newline with HTML tag
  ["\n",        '<br/>'                         ],
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

module RegexpConvertNode
  def to_body
    t = ERB::Util::html_escape(text_value)
    # Find each conversion until it's exhausted
    TagConversions.each do |tcd|
      tag, conv = tcd
      # Match prefix greedily, so that we only get the last matching tag.  Match contents lazily, so that we do not span across the potential tag borders.
      # Note the multiline mode, as we want the bold text to span across line breaks
      # Check how many arguments there are in the conv, and reason about tag format
      case conv.arity
      when 0
        # Regexp is (...)[tag](...)
        rx = /^(.*)\[#{tag}\](.*)$/m
        while md = t.match(rx)
          t = md[1] + conv[] + md[2]
        end
      when 1
        # Regexp is (...)[tag](...)[/tag](...)
        rx = /^(.*)\[#{tag}\](.*?)\[\/#{tag}\](.*)$/m
        while md = t.match(rx)
          t = md[1] + conv[md[2]] + md[3]
        end
      when 2
        # Regexp is (...)[tag=(...)](...)[/tag](...)
        rx = /^(.*)\[#{tag}=([^\]]*)\](.*?)\[\/#{tag}\](.*)$/m
        while md = t.match(rx)
          t = md[1] + conv[md[3],md[2]] + md[4]
        end
      end
    end
    # Now apply the other replacements
    Replacements.each do |rcd|
      replace, with = rcd
      t.gsub!(replace,with)
    end
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

  def self.filter(text, method = :to_body)
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


