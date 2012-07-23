// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.

// What happens when a user clicks show/hide on a post.  PBSH = "post bosy show/hide"
var pbsh_request = {};
var animation_time = 88;
function pbsh_maker(post_id, dont_hide, expand_id)
// dont_hide -- whether we should NOT hide the post if it's already been shown
// expand_id -- what thread is this beinf expanded because of
{
  // The element that will be spawned, with the body
  body_elem = $("#pb"+post_id);
  if (body_elem.length > 0) {
    if (!dont_hide || !body_elem.is(':visible')) {
      body_elem.slideToggle(animation_time);
    }
    // Remove "in progress" marks that might have been installed by progress triggers
    $("#p"+post_id).find('a.postbody').first().removeClass('inprogress');
    // Show that this was expanded due to some thread
    if (expand_id) stop_expansion_progress_on(expand_id);
  } else {
    // The element does not exist; create by querying the ajax post body request
    // Prevent duplicate requests
    if (!pbsh_request[post_id]){
      $("#p"+post_id).find('a.postbody').first().addClass('inprogress');
      /* Oh, no... Javascript doesn't have closures.  We can't rely on outer variables! */
      pbsh_request[post_id] = $.ajax({
        url: "/p/"+post_id+'.json',
        dataType: 'json',
        success: function(data) {
          post_id = data.id;
          orig_elem = $("#p"+post_id);
          orig_elem.find('a.postbody').first().removeClass('inprogress');
          // Show that this was expanded due to some thread
          if (expand_id) stop_expansion_progress_on(expand_id);
          $('<div id="pb'+post_id+'" class="postbody">'+data.body+'</div>').hide().appendTo(orig_elem).slideToggle(animation_time);
        },
        complete: function() { pbsh_request[post_id] = null }
      });
    }
  }
}

// I don't know if JS has currying... sorry!
function pbsh(post_id) {
  pbsh_maker(post_id, false)
}

// A hash of counters for children post bodies expansion procedures to check upon progress of (+++) mass-expand action
var expand_progresses = {};

// Call to decrease progress on a particular element, and to discard its inprogress class if none left
function stop_expansion_progress_on(elem_id)
{
  if (elem_id in expand_progresses){
    if (expand_progresses[elem_id] > 0){
      expand_progresses[elem_id] -= 1;
    }
    if (expand_progresses[elem_id] == 0){
      $('#'+elem_id).removeClass('inprogress');
    }
  }
}

/* Show/hide via Javascript */
var hidden_opposite = { 'show' : 'hide', 'hide': 'show', true: 'show', false: 'hide' };
// Translations
var hidden_str = { true : 'Show subtree', false: 'Hide subtree' };
// Initialize translations
function init_showhide(show_str, hide_str)
{
  hidden_str = { true : show_str, false: hide_str};
}
var shst_request = {};
// An event for a click
function showhide_subthread(post_id, do_hide, actor)
{
  actor.removeClass('show').removeClass('hide');
  // Fire a jsonp call
  shst_request[post_id] = $.ajax({
    url: "/p/"+post_id+'/toggle_showhide.js',
    dataType: 'jsonp',
    complete: function() { shst_request[post_id] = null }
  });
}

function replace_subthread_with(post_id, contents)
{
  ps = '#p'+post_id;
  // This won't let us find the correct destination element, but will find the "hidden bar," if any.
  maybe_hidden_bar = $(contents).find('#p'+post_id).next();
  // We infer if the post is now hidden from that HTML
  // We would've needed the "select-root" trick, but we wrapped our stuff carefully
  hidden = maybe_hidden_bar.hasClass('hidden-bar');
  actor = $(ps).find('a.subthread').first();
  actor.html(hidden_str[hidden]);
  actor.addClass(hidden_opposite[hidden]);
  actor.removeClass('inprogress');

  // The tree transformation works in two stages.  First, we remove everything that looks like children or a notification that they're hidden.  Then, we determine the relative position of the target div to the source in the new thread, and insert the target properly into this document.

  // First stage: remove everything that looks like children
  source = $('div'+ps);
  // This removes hidden mark and <ul> with children.
  source.next().remove();
  // This removes the next child (and all subsequent siblings) if it finds out that the next child contains 'sm' class (to distinguish benween a sibling and a smoothed child).
  // The trick to remove the parent and all subsequent siblings comes from http://stackoverflow.com/questions/8087371
  if (source.parent().next().children('.sm').length != 0){
    source.parent().nextAll().remove();
  }

  // Now find the target element(s) and show them at once
  // Determine if the target element is the immediate sibling of the new source one
  source_new = $(contents).find('div'+ps);
  immediate_new = source_new.next();
  if (immediate_new.length == 0){
    // It's not the sibling: show smoothed thread
    source_new.parent().nextAll().insertAfter(source.parent());
    // it's important to only rebind the new elements, to avoid repetition
    rebind_subthread_showhides(source.parent().nextAll().find('a'));
  }else{
    // It's the sibling: just append
    // the "wrap-parent" trick is to get outer html
    source.after(immediate_new.wrap('<a>').parent().html());
    // it's important to only rebind the new elements, to avoid repetition
    rebind_subthread_showhides(source.next().find('a'));
  }
}

// Binds events to show/hide subthread nodes in the current object
function rebind_subthread_showhides(jq)
{
  jq.filter('a.subthread').bind('click',function (event) {
    var $target = $(event.target);
    var post_id = $target.parent().attr('id').replace(/^p/,'');
    $target.addClass('inprogress');

    do_hide = $target.hasClass('hide');
    showhide_subthread(post_id,do_hide,$target);
    // Block the click
    return false;
  });
  /* Add "show only" custom event*/
  jq.filter('a.postbody').bind('showbody',function (event, trigger_id) {
    var $target = $(event.target);
    var post_id = $target.attr('id').replace(/^sh/,'');
    pbsh_maker(post_id, true, trigger_id);
    // Block the click
    return false;
  });

  /* This blocks default event (following the link) on all (+) links.  Used to prevent from junping to the top of the page.  It does stack with the inline onclick. */
  jq.filter('a.postbody').click(function (e) {
    return false;
  });

  /* Call that show-only event via special links */
  jq.filter('a.subthreadbody').click(function (event){
    // We are to trigger "expand" events at all proper children of this post.  This selector should get the div that wraps all children of this post.  We start from <a> link which is in header which is in the div we are looking for.
    var start_from = $(this).parent().parent();
    // Show that this is in progress, and initialize the progress counter
    $(this).addClass('inprogress');
    trigger_id = $(this).attr('id');
    expand_progresses[trigger_id] = start_from.find('a.postbody').size();
    // Launch expansion
    start_from.find('a.postbody').addClass('inprogress');
    start_from.find('a.postbody').trigger('showbody',trigger_id);
    // Block the click
    return false;
  });
}

jQuery(function($) {
  /* Moved to a separate function due to ajax subtree showhides */
  rebind_subthread_showhides($('a'));
});

