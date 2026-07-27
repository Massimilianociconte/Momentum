/* Pannello admin blog Momentum — SPA vanilla, API su stesso host. */
/* global toastui */
(function () {
  'use strict';

  var state = {
    slug: null, // null = nuovo articolo
    sha: null,
    draft: true,
    pubDate: '',
    articles: [],
  };

  var editor = null;

  var $ = function (id) { return document.getElementById(id); };

  // ---------- API ----------

  function api(path, options) {
    options = options || {};
    options.headers = Object.assign(
      { 'Content-Type': 'application/json' },
      options.headers || {},
    );
    options.credentials = 'same-origin';

    return fetch(path, options).then(function (response) {
      if (response.status === 401 && path !== '/api/login') {
        showView('login');
        throw new Error('Sessione scaduta, accedi di nuovo.');
      }
      return response.json().then(function (body) {
        if (!response.ok) {
          throw new Error(body.error || 'Errore ' + response.status);
        }
        return body;
      });
    });
  }

  // ---------- Viste ----------

  function showView(name) {
    ['login', 'list', 'editor'].forEach(function (view) {
      $('view-' + view).hidden = view !== name;
    });
    $('topbar-actions').hidden = name === 'login';
    window.scrollTo(0, 0);
  }

  function toast(message, isError) {
    var element = $('toast');
    element.textContent = message;
    element.className = 'toast' + (isError ? ' toast--error' : '');
    element.hidden = false;
    clearTimeout(element._timer);
    element._timer = setTimeout(function () { element.hidden = true; }, 4000);
  }

  // ---------- Login ----------

  $('form-login').addEventListener('submit', function (event) {
    event.preventDefault();
    $('login-error').hidden = true;
    $('btn-login').disabled = true;

    api('/api/login', {
      method: 'POST',
      body: JSON.stringify({ password: $('input-password').value }),
    })
      .then(function () {
        $('input-password').value = '';
        openList();
      })
      .catch(function () {
        $('login-error').hidden = false;
      })
      .finally(function () {
        $('btn-login').disabled = false;
      });
  });

  $('btn-logout').addEventListener('click', function () {
    api('/api/logout', { method: 'POST' }).finally(function () {
      showView('login');
    });
  });

  // ---------- Lista ----------

  function openList() {
    showView('list');
    $('article-list').innerHTML = '<p class="muted">Caricamento…</p>';
    $('list-empty').hidden = true;

    api('/api/articles')
      .then(function (body) {
        state.articles = body.articles;
        renderList();
      })
      .catch(function (error) {
        $('article-list').innerHTML = '';
        toast(error.message, true);
      });
  }

  function renderList() {
    var query = $('input-search').value.trim().toLowerCase();
    var container = $('article-list');
    container.innerHTML = '';

    var visible = state.articles.filter(function (article) {
      return (
        !query ||
        article.title.toLowerCase().indexOf(query) !== -1 ||
        article.slug.indexOf(query) !== -1
      );
    });

    $('list-empty').hidden = visible.length > 0;

    visible.forEach(function (article) {
      var card = document.createElement('button');
      card.type = 'button';
      card.className = 'article-card';

      var title = document.createElement('div');
      title.className = 'article-card__title';
      title.textContent = article.title;

      var meta = document.createElement('div');
      meta.className = 'article-card__meta';

      var badge = document.createElement('span');
      badge.className = 'badge ' + (article.draft ? 'badge--draft' : 'badge--published');
      badge.textContent = article.draft ? 'Bozza' : 'Pubblicato';

      meta.appendChild(badge);
      meta.appendChild(document.createTextNode(article.pubDate + ' · ' + article.slug));

      card.appendChild(title);
      card.appendChild(meta);
      card.addEventListener('click', function () { openEditor(article.slug); });
      container.appendChild(card);
    });
  }

  $('input-search').addEventListener('input', renderList);
  $('btn-new').addEventListener('click', function () { openEditor(null); });

  // ---------- Editor ----------

  function ensureEditor(initialValue) {
    if (editor) {
      editor.setMarkdown(initialValue || '', false);
      return;
    }

    editor = new toastui.Editor({
      el: $('editor'),
      initialEditType: 'wysiwyg',
      previewStyle: 'tab',
      height: '58vh',
      theme: 'dark',
      usageStatistics: false,
      initialValue: initialValue || '',
      placeholder: 'Scrivi qui il contenuto dell\u2019articolo\u2026',
      hooks: { addImageBlobHook: onImageUpload },
    });
  }

  function openEditor(slug) {
    state.slug = slug;
    state.sha = null;
    state.draft = true;
    state.pubDate = '';

    showView('editor');
    $('save-status').hidden = true;
    $('gallery').innerHTML = '';

    if (!slug) {
      fillFields({});
      ensureEditor('');
      updateEditorChrome();
      return;
    }

    ensureEditor('Caricamento\u2026');

    api('/api/articles/' + slug)
      .then(function (body) {
        state.sha = body.sha;
        state.draft = body.frontmatter.draft !== false;
        state.pubDate = body.frontmatter.pubDate || '';
        fillFields(body.frontmatter);
        editor.setMarkdown(body.bodyMarkdown || '', false);
        updateEditorChrome();
        loadGallery();
      })
      .catch(function (error) {
        toast(error.message, true);
        openList();
      });
  }

  function fillFields(frontmatter) {
    $('f-title').value = frontmatter.title || '';
    $('f-description').value = frontmatter.description || '';
    $('f-seo-title').value = frontmatter.seoTitle || '';
    $('f-category').value = frontmatter.category || '';
    $('f-author').value = frontmatter.author || '';
    $('f-tags').value = Array.isArray(frontmatter.tags) ? frontmatter.tags.join(', ') : '';
    $('f-featured').value = frontmatter.featuredImage || '';
    $('f-featured-alt').value = frontmatter.featuredImageAlt || '';
    updateDescriptionCount();
  }

  function collectFields() {
    return {
      title: $('f-title').value.trim(),
      description: $('f-description').value.trim(),
      bodyMarkdown: editor ? editor.getMarkdown().trim() : '',
      seoTitle: $('f-seo-title').value.trim(),
      category: $('f-category').value.trim(),
      author: $('f-author').value.trim(),
      tags: $('f-tags').value.split(',').map(function (tag) { return tag.trim(); }).filter(Boolean),
      featuredImage: $('f-featured').value.trim(),
      featuredImageAlt: $('f-featured-alt').value.trim(),
    };
  }

  function updateEditorChrome() {
    var status = $('editor-status');

    if (!state.slug) {
      status.textContent = 'Nuovo articolo';
      status.className = 'badge badge--draft';
    } else {
      status.textContent = state.draft ? 'Bozza' : 'Pubblicato';
      status.className = 'badge ' + (state.draft ? 'badge--draft' : 'badge--published');
    }

    $('btn-publish').textContent = state.draft ? 'Pubblica' : 'Riporta in bozza';
    $('btn-publish').disabled = !state.slug;
    $('btn-delete').disabled = !state.slug;
  }

  function updateDescriptionCount() {
    $('desc-count').textContent = String($('f-description').value.length);
  }

  $('f-description').addEventListener('input', updateDescriptionCount);
  $('btn-back').addEventListener('click', openList);

  // ---------- Salvataggio ----------

  $('btn-save').addEventListener('click', function () {
    var fields = collectFields();

    if (!fields.title || !fields.description) {
      toast('Titolo e descrizione sono obbligatori.', true);
      return;
    }

    $('btn-save').disabled = true;

    var request;
    if (!state.slug) {
      request = api('/api/articles', {
        method: 'POST',
        body: JSON.stringify(fields),
      });
    } else {
      request = api('/api/articles/' + state.slug, {
        method: 'PUT',
        body: JSON.stringify(Object.assign(fields, {
          sha: state.sha,
          draft: state.draft,
          pubDate: state.pubDate,
        })),
      });
    }

    request
      .then(function (body) {
        state.slug = body.slug;
        state.sha = body.sha;
        updateEditorChrome();
        showSaveStatus(body.commitUrl);
        toast('Salvato \u2713');
      })
      .catch(function (error) {
        toast(error.message, true);
      })
      .finally(function () {
        $('btn-save').disabled = false;
      });
  });

  $('btn-publish').addEventListener('click', function () {
    if (!state.slug) { return; }

    var target = !state.draft;
    var label = target ? 'Riportare in bozza' : 'Pubblicare';
    if (!window.confirm(label + ' \u00ab' + $('f-title').value + '\u00bb?')) {
      return;
    }

    $('btn-publish').disabled = true;

    api('/api/articles/' + state.slug + '/draft', {
      method: 'POST',
      body: JSON.stringify({ draft: target }),
    })
      .then(function (body) {
        state.draft = body.draft;
        state.sha = body.sha;
        updateEditorChrome();
        showSaveStatus(body.commitUrl);
        toast(body.draft ? 'Riportato in bozza' : 'Pubblicato \u2713');
      })
      .catch(function (error) {
        toast(error.message, true);
      })
      .finally(function () {
        $('btn-publish').disabled = false;
      });
  });

  $('btn-delete').addEventListener('click', function () {
    if (!state.slug) { return; }
    if (!window.confirm('Eliminare definitivamente \u00ab' + $('f-title').value + '\u00bb?')) {
      return;
    }

    api('/api/articles/' + state.slug, { method: 'DELETE' })
      .then(function () {
        toast('Articolo eliminato');
        openList();
      })
      .catch(function (error) {
        toast(error.message, true);
      });
  });

  function showSaveStatus(commitUrl) {
    var status = $('save-status');
    status.hidden = false;
    status.innerHTML = '';
    status.appendChild(document.createTextNode('Commit creato — il sito si aggiorna in ~2 minuti. '));

    if (commitUrl) {
      var link = document.createElement('a');
      link.href = commitUrl;
      link.target = '_blank';
      link.rel = 'noopener';
      link.textContent = 'Vedi commit';
      status.appendChild(link);
    }
  }

  // ---------- Immagini ----------

  function onImageUpload(blob, callback) {
    if (!state.slug) {
      toast('Salva prima la bozza, poi potrai caricare immagini.', true);
      return;
    }

    var reader = new FileReader();
    reader.onload = function () {
      api('/api/images', {
        method: 'POST',
        body: JSON.stringify({
          slug: state.slug,
          filename: blob.name || 'immagine.png',
          contentBase64: String(reader.result),
        }),
      })
        .then(function (body) {
          callback(body.path, blob.name || 'immagine');
          toast('Immagine caricata \u2713');
          loadGallery();
        })
        .catch(function (error) {
          toast(error.message, true);
        });
    };
    reader.readAsDataURL(blob);
  }

  function loadGallery() {
    if (!state.slug) { return; }

    api('/api/images/' + state.slug).then(function (body) {
      var gallery = $('gallery');
      gallery.innerHTML = '';

      body.images.forEach(function (image) {
        var thumbnail = document.createElement('img');
        thumbnail.src = image.path;
        thumbnail.alt = image.name;
        thumbnail.title = 'Usa come copertina: ' + image.name;
        thumbnail.addEventListener('click', function () {
          $('f-featured').value = image.path;
          toast('Impostata come copertina');
        });
        gallery.appendChild(thumbnail);
      });
    }).catch(function () { /* galleria opzionale */ });
  }

  // ---------- Avvio ----------

  api('/api/session')
    .then(function () { openList(); })
    .catch(function () { showView('login'); });
})();
