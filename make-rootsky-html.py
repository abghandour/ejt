#!/usr/bin/env python3
"""Copy wordsky.html -> rootsky.html with modifications."""

with open('wordsky.html', 'r', encoding='utf-8') as f:
    html = f.read()

# 1. Replace data source: wordsky.json -> rootsky.json
html = html.replace("fetch('wordsky.json')", "fetch('rootsky.json')")

# 2. Replace localStorage keys: wordsky_ -> rootsky_
html = html.replace("'wordsky_state_'", "'rootsky_state_'")
html = html.replace("'wordsky_history'", "'rootsky_history'")

# 3. Replace title
html = html.replace('Wordsky — Daily Russian Word Game', 'Rootsky — Daily Russian Root Game')

# 4. Replace display text instances of Wordsky -> Rootsky
html = html.replace('Wordsky Results', 'Rootsky Results')
html = html.replace('Wordsky ', 'Rootsky ')  # share text prefix
html = html.replace("alt=\"Wordsky banner\"", "alt=\"Rootsky banner\"")
html = html.replace("'wordsky-results.png'", "'rootsky-results.png'")

# 5. Add root-info element to word-display-area HTML
old_word_display = '''<!-- Word Display Area -->
<div id="word-display-area">
  <div id="russian-word">—</div>'''

new_word_display = '''<!-- Word Display Area -->
<div id="word-display-area">
  <div id="root-info"><span id="root-word"></span> <span id="root-translation"></span></div>
  <div id="russian-word">—</div>'''

html = html.replace(old_word_display, new_word_display)

# 6. Add CSS for root-info (insert before the #word-display-area rule)
root_info_css = """/* ===== ROOT INFO ===== */
#word-display-area{
  position:relative;
}
#root-info{
  position:absolute;
  top:8px;
  left:12px;
  display:flex;
  align-items:baseline;
  gap:6px;
  z-index:1;
}
#root-word{
  font-size:16px;
  font-weight:700;
  color:#c8a830;
  text-shadow:0 0 10px rgba(200,168,48,0.3);
}
#root-translation{
  font-size:12px;
  color:#6a6a8a;
  font-style:italic;
}

"""

# Insert before the existing #word-display-area CSS block
html = html.replace('/* ===== WORD DISPLAY ===== */\n#word-display-area{',
                     '/* ===== WORD DISPLAY ===== */\n' + root_info_css + '#word-display-area{')

# 7. Add JS to update root-info in renderWord function
# After setting russianEl.textContent, add root info update
old_render = """  function renderWord(wordEntry, wordIndex, disabledOptions) {
    var russianEl = document.getElementById('russian-word');
    russianEl.textContent = wordEntry.wordOfTheDay;"""

new_render = """  function renderWord(wordEntry, wordIndex, disabledOptions) {
    var russianEl = document.getElementById('russian-word');
    russianEl.textContent = wordEntry.wordOfTheDay;

    // Update root info
    var rootWordEl = document.getElementById('root-word');
    var rootTransEl = document.getElementById('root-translation');
    if (rootWordEl) rootWordEl.textContent = wordEntry.rootWord || '';
    if (rootTransEl) rootTransEl.textContent = wordEntry.rootTranslation ? '(' + wordEntry.rootTranslation + ')' : '';"""

html = html.replace(old_render, new_render)

# 8. Also update root-info in renderReviewWord
old_review = """  function renderReviewWord(index) {
    if (!currentWords || !currentWords[index]) return;
    var wordEntry = currentWords[index];

    var russianEl = document.getElementById('russian-word');
    russianEl.textContent = wordEntry.wordOfTheDay;"""

new_review = """  function renderReviewWord(index) {
    if (!currentWords || !currentWords[index]) return;
    var wordEntry = currentWords[index];

    var russianEl = document.getElementById('russian-word');
    russianEl.textContent = wordEntry.wordOfTheDay;

    // Update root info
    var rootWordEl = document.getElementById('root-word');
    var rootTransEl = document.getElementById('root-translation');
    if (rootWordEl) rootWordEl.textContent = wordEntry.rootWord || '';
    if (rootTransEl) rootTransEl.textContent = wordEntry.rootTranslation ? '(' + wordEntry.rootTranslation + ')' : '';"""

html = html.replace(old_review, new_review)

with open('rootsky.html', 'w', encoding='utf-8') as f:
    f.write(html)

print("Done — rootsky.html created")
