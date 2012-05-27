// Place all the behaviors and hooks related to the matching controller here.
// All this logic will automatically be available in application.js.

// What happens when a user clicks show/hide on a post.  PBSH = "post bosy show/hide"
var pbsh_request = {};
function pbsh_maker(post_id, dont_hide)
{
  // The element that will be spawned, with the body
  body_elem = $("#pb"+post_id);
  if (body_elem.length > 0) {
    if (!dont_hide || !body_elem.is(':visible')) {
      body_elem.slideToggle();
    }
    // Remove "in progress" marks that might have been installed by progress triggers
    $("#p"+post_id).find('a.postbody').first().removeClass('inprogress');
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
          $('<div id="pb'+post_id+'" class="postbody">'+data.body+'</div>').hide().appendTo(orig_elem).slideToggle();
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

jQuery(function($) {
  /* Add "show only" custom event*/
  $('a.postbody').bind('showbody',function (event) {
    var $target = $(event.target);
    var post_id = $target.attr('id').replace(/^sh/,'');
    pbsh_maker(post_id, true)
  });

  /* Call that show-only event via special links */
  $('a.subthreadbody').click(function (event){
    $(this).closest('li').find('a.postbody').addClass('inprogress');
    $(this).closest('li').find('a.postbody').trigger('showbody');
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
