# coding: utf-8
require 'treetop'
require 'erb'

# The actual value does not matter now, it will be reset at filter() call
# NOTE that this is a global variable, so we can't parse concurrently.  Each process, however, has its own scope, and should not affect what happens in other processes.
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
  # Links are also created when user posts an URL in the body of their post.  It also should set the same $c attribute!
  ['url',      proc {|inner,url| $c.sign[:url] = true;  %Q(<a href="#{url}" target=_blank>#{inner}</a>)}],
  # [pic] is checked for when converting URLs in the post body, FIXME
  ['pic',      proc {|inner| $c.sign[:pic] = true;  %Q(<img class="imgtag" src="#{inner}"/>)}],
  ['hr',       proc {|| %Q(<hr/>)}],
  ['tab',      proc {|| %Q(&nbsp;)*9}],
  ['q',        proc {|inner| pre = %Q(<blockquote><span class="inquote">[q]</span><b>Quote:</b><br/>); $c.search_after = pre.length; %Q(#{pre}#{inner}<span class="inquote">[/q]</span></blockquote>)}],
  ['center',   proc {|inner| %Q(<center>#{inner}</center>)}],
  # [pre] is handled in the parser
  ['strike',   proc {|inner| %Q(<strike>#{inner}</strike>)}],
  ['sub',      proc {|inner| %Q(<sub>#{inner}</sub>)}],
  ['sup',      proc {|inner| %Q(<sup>#{inner}</sup>)}],
  # [tex] is handled in the parser
  # [tub] is checked for when converting URLs in the post body, FIXME
  ['tub',      proc {|inner| $c.sign[:vid] = true;  %Q(<iframe class="youtube-player" type="text/html" width="640" height="390" src="http://www.youtube.com/embed/#{inner}?iv_load_policy=3&rel=0&fs=1" frameborder="0"></iframe>)}],
  ['spoiler',  proc{|inner| %Q(<span style="spoiler">#{inner}</span>)}],
]

def wrap(tag,wtf,close_tag = nil); %Q(wrap('[#{tag}]', '[/#{close_tag ? close_tag : tag}]', #{wtf});); end
def _wrap(open,wtf,close); %Q(wrap('#{open}', '#{close}', #{wtf});); end

dbr = {:name => ''}
tag_buttons = {
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
  'smile' => dbr.merge({:name => 'smile', :accesskey => "0", :style => "width: 55px", :title => "таблица смайлов (alt+0)", :onclick => 'show();'}),
}

# NOTE: the lambdas created in TagConversions will be evaluated in a special context, which is supplied by the caller, and is read by it as well.

# Add your own replacements here
usual_replacements = [
  # Replace newlines with HTML tag (but save the line breaks for a nicer view)
  ["\r\n",      "<br/>"                         ],
  # the next matches only after the previous one is exhausted
  ["\n",        "<br/>"                         ],
  # indent with 9 non-breaking spaces
  ["^\t",       "&nbsp;" * 9                    ],
]
 
# SMILEYS
# =======
#
# TODO : move this to app.config
# Unfortunately, we can't use asset pipeline here, as this file is loaded _before_ the assets!
# So we put smileys into the "public" folder, and print the direct html
def make_smiley(smn)
  %Q(<img src="/images/smileys/#{smn}"/>)
end

SMILE_REGISTRY = {
  ":))"       => { :html => make_smiley("bigsmile.gif")},
  ":)"        => { :html => make_smiley("smile.gif")},
  ":("        => { :html => make_smiley("frown.gif")},
  ";)"        => { :html => make_smiley("wink.gif")},
  ":!!"       => { :html => make_smiley("lol.gif")},
  ":\\"       => { :html => make_smiley("smirk.gif")},
  ":o"        => { :html => make_smiley("redface.gif")},
  ":MAD"      => { :html => make_smiley("mad.gif")},
  ":STOP"     => { :html => make_smiley("stop.gif")},
  ":APPL"     => { :html => make_smiley("appl.gif")},
  ":BAN"      => { :html => make_smiley("ban.gif")},
  ":BEE"      => { :html => make_smiley("bee.gif")},
  ":ZLOBA"    => { :html => make_smiley("blya.gif")},
  ":BORED"    => { :html => make_smiley("bored.gif")},
  ":BOTAT"    => { :html => make_smiley("botat.gif")},
  ":BIS"      => { :html => make_smiley("bis.gif")},
  ":COMP"     => { :html => make_smiley("comp.gif")},
  ":CRAZY"    => { :html => make_smiley("crazy.gif")},
  ":DEVIL"    => { :html => make_smiley("devil.gif")},
  ":DOWN"     => { :html => make_smiley("down.gif")},
  ":FIGA"     => { :html => make_smiley("figa.gif")},
  ":GIT"      => { :html => make_smiley("git.gif")},
  ":GYGY"     => { :html => make_smiley("gy.gif")},
  ":HEH"      => { :html => make_smiley("heh.gif")},
  ":CIQ"      => { :html => make_smiley("iq.gif")},
  ":KURIT"    => { :html => make_smiley("kos.gif")},
  ":LAM"      => { :html => make_smiley("lam.gif")},
  ":MNC"      => { :html => make_smiley("mnc.gif")},
  ":NO"       => { :html => make_smiley("no.gif")},
  ":SMOKE"    => { :html => make_smiley("smoke.gif")},
  ":SORRY"    => { :html => make_smiley("sorry.gif")},
  ":SUPER"    => { :html => make_smiley("super.gif")},
  ":UP"       => { :html => make_smiley("up.gif")},
  ":YES2"     => { :html => make_smiley("yes2.gif")},
  ":YES"      => { :html => make_smiley("yes.gif")},
  ":BASH"     => { :html => make_smiley("bash.gif")},
  ":CLAPPY"   => { :html => make_smiley("clappy.gif")},
  ":EWW"      => { :html => make_smiley("eww.gif")},
  ":ROTFL"    => { :html => make_smiley("roflol.gif")},
  ":SPOTMAN"  => { :html => make_smiley("spotman.gif")},
  ":WAVE"     => { :html => make_smiley("wave.gif")},
  ":COWARD"   => { :html => make_smiley("coward.gif")},
  ":DRAZNIT"  => { :html => make_smiley("draznit.gif")},
  ":PLOHO"    => { :html => make_smiley("blevalyanaeto.gif")},
  ":ROLLEYES" => { :html => make_smiley("rolleyes.gif")},
  ":}"        => { :html => make_smiley("icqbig.gif")},
}

smile_replacements = SMILE_REGISTRY.map{|code,v| [code, v[:html]]}

# Compute button and tag registries
Replacements = usual_replacements + smile_replacements

BUTTON_REGISTRY = SMILE_REGISTRY.inject(tag_buttons.dup){|acc,kv| acc[kv[0]] = {:title => kv[0], :onclick => "insert(' #{kv[0]} ',0)", :html => kv[1][:html]}; acc}

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
  attr_accessor :sign, :search_after
  def initialize
    @sign = {}
  end
  def get_binding
    return binding
  end
end

module RegexpConvertNode
  # Matches an URL in a string, the url not being a part of a boardtag.  Returns matchdata
  def match_url_in(string)
    # The regexp should detect URLs with ports, and do not include the trailing punctuation in 'http://ya.ru.' or 'http://ya.ru/url/.'
    # The beginning and the end contain lookahead assumptions to rule out converting links that are inside URL tags.
    # Match:      not-tag     protocol           // path                         country     ( port(if any), the rest, last should be an alnum) if any
    /(?<!\[url=|\[pic\]|\[tub.)(http|https|ftp):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}((:[0-9]{1,5})?[a-z0-9_\-\.%\/?#=&\@:!]*[a-z0-9_\-\/#\@:!])?(?!\])/im.match(string)
  end
  module_function :match_url_in

  include ERB::Util
  def to_body
    # The HTML-escaping will be performed inside the HTML-conversion loop, so that we properly convert links with ampersands.
    t = text_value
    # Now convert URLs to links
    result = ''
    to_convert = t
    while not to_convert.empty?
      if md = match_url_in(to_convert)
        result << h(md.pre_match) << %Q(<a href="#{md[0].html_safe}">#{h md[0]}</a>)
        to_convert = md.post_match
        # Set post's attribute.  Do not forget to sync with [url] tag callback!
        $c.sign[:url] = true
      else
        # No more URLs left, returning
        result += h(to_convert)
        to_convert = ''
      end
    end
    # The string is already HTML-safe at this point -- see these h() calls to non-URL parts above
    t = result

    # Find each conversion until it's exhausted
    TagConversions.each do |tcd|
      tag, conv = tcd
      # Match prefix greedily, so that we only get the last matching tag.  Match contents lazily, so that we do not span across the potential tag borders.
      # Note the regexp multiline mode, as we want the formatted text to span across line breaks.
      # Note also the unicode in messages
      # We use html_safe to make Rails not html-escape strings on concatenation.
      # Check how many arguments there are in the conv, and reason about tag format
      # Note that we read position specification from tag conversion.  This is to prevent recursive expanding of tags if the result of the conversion contains the original tag (i.e. [q]...[/q] -> <blockquote>[q]...[/q]</blockquote>.)
      start_pos = 0
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
        while md = t.match(rx,start_pos)
          t = md[1] + conv[md[2]].html_safe + md[3]
          start_pos = $c.search_after ? (md[1].length + $c.search_after) : 0
        end
      when 2
        # Regexp is (...)[tag=(...)](...)[/tag](...)
        rx = /^(.*)\[#{tag}=([^\]]*)\](.*?)\[\/#{tag}\](.*)$/mu
        while md = t.match(rx,start_pos)
          t = md[1] + conv[md[3],md[2]].html_safe + md[4]
          start_pos = $c.search_after ? (md[1].length + $c.search_after) : 0
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


