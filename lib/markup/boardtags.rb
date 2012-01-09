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
      # Note the regexpmultiline mode, as we want the formatted text to span across line breaks.
      # We use html_safe to make Rails not html-escape strings on concatenation.
      # Check how many arguments there are in the conv, and reason about tag format
      case conv.arity
      when 0
        # Regexp is (...)[tag](...)
        rx = /^(.*)\[#{tag}\](.*)$/m
        while md = t.match(rx)
          t = md[1] + conv[].html_safe + md[2]
        end
      when 1
        # Regexp is (...)[tag](...)[/tag](...)
        rx = /^(.*)\[#{tag}\](.*?)\[\/#{tag}\](.*)$/m
        while md = t.match(rx)
          t = md[1] + conv[md[2]].html_safe + md[3]
        end
      when 2
        # Regexp is (...)[tag=(...)](...)[/tag](...)
        rx = /^(.*)\[#{tag}=([^\]]*)\](.*?)\[\/#{tag}\](.*)$/m
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

  def self.filter(text, method = :to_body, context = DefaultParseContext.new)
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


