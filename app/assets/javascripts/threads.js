// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.

// What happens when a user clicks show/hide on a post.  PBSH = "post bosy show/hide"
var pbsh_request;
function pbsh(post_id)
{
  // The post header
  orig_elem = $("#p"+post_id);
  // The element that will be spawned, with the body
  body_elem = $("#pb"+post_id);
  if (body_elem.length > 0) {
    body_elem.slideToggle();
  } else {
    // The element does not exist; create by querying the ajax post body request
    // Prevent duplicate requests
    if (!pbsh_request){
      pbsh_request = $.ajax({
        url: "/p/"+post_id+'.json',
        dataType: 'json',
        success: function(data) {
          $('<div id="pb'+post_id+'" class="postbody">'+data.body+'</div>').hide().appendTo(orig_elem).slideToggle();
        },
        complete: function() { pbsh_request = null }
      });
    }
  }
}

jQuery(function($) {
  /* This blocks default event (following the link) on all (+) links.  Used to prevent from junping to the top of the page.  It does stack with the inline onclick. */
  $('a.postbody').click(function (e) {
    return false;
  });
})
