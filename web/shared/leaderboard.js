/* ===== LEADERBOARD MODAL ===== */
/* Call showLeaderboard(game, language, difficulty) from any game page */

function showLeaderboard(game, language, difficulty) {
  // Remove existing modal if any
  var existing = document.getElementById('leaderboard-modal');
  if (existing) existing.remove();

  var modal = document.createElement('div');
  modal.id = 'leaderboard-modal';
  modal.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;z-index:10000;background:rgba(0,0,0,0.85);display:flex;align-items:center;justify-content:center;backdrop-filter:blur(4px);-webkit-backdrop-filter:blur(4px);';

  var inner = document.createElement('div');
  inner.style.cssText = 'background:var(--bg-card,#1e1e3a);border:1px solid var(--border-subtle,#333);border-radius:16px;width:90%;max-width:400px;max-height:80vh;overflow:hidden;display:flex;flex-direction:column;';

  // Header
  var header = document.createElement('div');
  header.style.cssText = 'padding:16px 20px;border-bottom:1px solid var(--border-subtle,#333);display:flex;align-items:center;justify-content:space-between;';
  header.innerHTML = '<span style="font-family:\'Press Start 2P\',monospace;font-size:11px;color:var(--accent,#c8a830);">Leaderboard</span>';
  var closeBtn = document.createElement('button');
  closeBtn.textContent = '\u2715';
  closeBtn.style.cssText = 'background:none;border:none;color:var(--text-secondary,#888);font-size:18px;cursor:pointer;padding:4px 8px;';
  closeBtn.addEventListener('click', function() { modal.remove(); });
  header.appendChild(closeBtn);
  inner.appendChild(header);

  // Body (scrollable)
  var body = document.createElement('div');
  body.style.cssText = 'padding:12px 20px;overflow-y:auto;flex:1;';
  body.innerHTML = '<div style="text-align:center;color:var(--text-secondary,#888);padding:20px;">Loading...</div>';
  inner.appendChild(body);

  modal.appendChild(inner);
  modal.addEventListener('click', function(e) { if (e.target === modal) modal.remove(); });
  document.body.appendChild(modal);

  // Fetch leaderboard
  getLeaderboard(game, language, difficulty, 20).then(function(entries) {
    if (entries.length === 0) {
      var html = '<div style="text-align:center;color:var(--text-secondary,#888);padding:20px;">No scores yet. Be the first!</div>';
      if (typeof isSubscriber === 'function' && !isSubscriber()) {
        html += '<div style="text-align:center;margin-top:12px;"><button onclick="loginWithPatreon()" style="padding:10px 20px;font-family:\'Roboto Condensed\',sans-serif;font-weight:700;font-size:13px;background:var(--accent,#c8a830);color:var(--bg-primary,#0e0e1a);border:none;border-radius:8px;cursor:pointer;">Login to submit scores</button></div>';
      }
      body.innerHTML = html;
      return;
    }
    var html = '<table style="width:100%;border-collapse:collapse;">';
    html += '<tr style="color:var(--text-secondary,#888);font-size:11px;text-transform:uppercase;"><td style="padding:4px 0;">#</td><td>Player</td><td style="text-align:right;">Score</td></tr>';
    entries.forEach(function(e) {
      var rowStyle = e.is_me ? 'background:var(--accent-subtle,rgba(200,168,48,0.15));border-radius:6px;' : '';
      var nameStyle = e.is_me ? 'font-weight:700;color:var(--accent,#c8a830);' : 'color:var(--text-primary,#eee);';
      html += '<tr style="' + rowStyle + '">';
      html += '<td style="padding:8px 4px;font-size:13px;color:var(--text-secondary,#888);">' + e.rank + '</td>';
      html += '<td style="padding:8px 4px;font-size:14px;' + nameStyle + '">' + e.display_name + '</td>';
      html += '<td style="padding:8px 4px;font-size:14px;text-align:right;color:var(--text-primary,#eee);font-weight:700;">' + e.score + '</td>';
      html += '</tr>';
    });
    html += '</table>';
    if (typeof isSubscriber === 'function' && !isSubscriber()) {
      html += '<div style="text-align:center;margin-top:16px;padding-top:12px;border-top:1px solid var(--border-subtle,#333);"><button onclick="loginWithPatreon()" style="padding:10px 20px;font-family:\'Roboto Condensed\',sans-serif;font-weight:700;font-size:13px;background:var(--accent,#c8a830);color:var(--bg-primary,#0e0e1a);border:none;border-radius:8px;cursor:pointer;">Login to submit your scores</button></div>';
    }
    body.innerHTML = html;
  });
}
