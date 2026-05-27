window.onload = function() {
  var overlay = document.createElement('div');
  overlay.id = 'lightbox';
  overlay.innerHTML = '<img id="lightbox-img" src="" />';
  document.body.appendChild(overlay);

  document.querySelectorAll('#content img').forEach(function(img) {
    img.addEventListener('click', function() {
      document.getElementById('lightbox-img').src = img.src;
      overlay.classList.add('active');
    });
  });

  overlay.addEventListener('click', function() {
    overlay.classList.remove('active');
  });

  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') overlay.classList.remove('active');
  });
};
