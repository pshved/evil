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

jQuery(function($) {
  /* Add "show only" custom event*/
  $('a.postbody').bind('showbody',function (event, trigger_id) {
    var $target = $(event.target);
    var post_id = $target.attr('id').replace(/^sh/,'');
    pbsh_maker(post_id, true, trigger_id);
  });

  /* Call that show-only event via special links */
  $('a.subthreadbody').click(function (event){
    // We are to trigger "expand" events at all proper children of this post.  This selector should get the div that wraps all children of this post.  We start from <a> link which is in header which is in the div we are looking for.
    var start_from = $(this).parent().parent();
    // Show that this is in progress, and initialize the progress counter
    $(this).addClass('inprogress');
    trigger_id = $(this).attr('id');
    expand_progresses[trigger_id] = start_from.find('a.postbody').size();
    // Launch expansion
    start_from.find('a.postbody').addClass('inprogress');
    start_from.find('a.postbody').trigger('showbody',trigger_id);
  });
});

jQuery(function($) {
  /* This blocks default event (following the link) on all (+) links.  Used to prevent from junping to the top of the page.  It does stack with the inline onclick. */
  $('a.postbody').click(function (e) {
    return false;
  });
  $('a.subthreadbody').click(function (e) {
    return false;
  });
});
