$(document).on("turbolinks:load", function() {
  const observer = new IntersectionObserver(
    ([e]) => e.target.classList.toggle("is-pinned", e.intersectionRatio < 1),
    { threshold: [1] }
  );
  $(".sticky-top").each(function() {
    observer.observe(this);
  });
});

