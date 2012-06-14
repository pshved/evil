// This is a manifest file that'll be compiled into including all the files listed below.
// Add new JavaScript/Coffee code in separate files in this directory and they'll automatically
// be included in the compiled file accessible from http://example.com/assets/application.js
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
//= require jquery
//= require jquery_ujs
//= require_tree .

function waitForSourcePost(iframe_name,source_name)
{
  var iframe_selector = 'iframe[name='+iframe_name+']'
  // At each frame load, we check if the frame designates a successful post.  If it does, then wait for it to be imported, ad redirect.
  $(iframe_selector).load(function (e) {
    href_elem = $(this).contents().find('p b a').first();
    if (href_elem.length > 0){
      var post_href = href_elem.attr('href');
      var post_regexp = /\?read=/;
      if (post_regexp.test(post_href)){
        // There is a link that follows to a post at the source forum, get the post id
        var post_id = post_href.replace(post_regexp,'');
        // Notify the source that it should notify the downloader
        $.get('/sources/'+source_name+'/instant');
        // Redirect the post as soon as it's imported (TODO + ajax)
        setTimeout(function(){window.location.replace("/sources/"+source_name+"/read/"+post_id);},5000);
      }
    }
  });
}

// a crippled version of post waiter that doesn't violate same origin policy
function waitForSourcePost_Crippled(iframe_name,onload_redirect_url)
{
  var iframe_selector = 'iframe[name='+iframe_name+']';
  var first_load = true;
  // At each frame load, we check if the frame designates a successful post.  If it does, then wait for it to be imported, ad redirect.
  $(iframe_selector).load(function (e) {
    // Redirect the post as soon as it's imported (TODO + ajax)
    if (! first_load){
      var curtime = new Date;
      // We do not send the current time because it may be not accurate.  See my_reply_to action in Sources controller for more description.
      //setTimeout(function(){window.location.replace(onload_redirect_url + "?after=" + curtime.toUTCString());},4000);
      setTimeout(function(){window.location.replace(onload_redirect_url);},4000);
    }
    first_load = false;
  });
}
