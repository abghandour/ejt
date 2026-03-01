// Helper drawing functions
function drawStar(ctx, cx, cy, r) {
  ctx.beginPath();
  for (let i = 0; i < 5; i++) {
    const a = -Math.PI/2 + i * Math.PI*2/5;
    const b = a + Math.PI/5;
    ctx.lineTo(cx + Math.cos(a)*r, cy + Math.sin(a)*r);
    ctx.lineTo(cx + Math.cos(b)*r*0.4, cy + Math.sin(b)*r*0.4);
  }
  ctx.closePath(); ctx.fill();
}

function drawOnionDome(ctx, cx, cy, rw, rh) {
  ctx.beginPath();
  ctx.moveTo(cx - rw, cy);
  ctx.quadraticCurveTo(cx - rw*1.2, cy - rh*0.6, cx, cy - rh);
  ctx.quadraticCurveTo(cx + rw*1.2, cy - rh*0.6, cx + rw, cy);
  ctx.closePath(); ctx.fill();
  const oldFill = ctx.fillStyle;
  ctx.fillStyle = "#c8a830";
  ctx.fillRect(cx-1, cy-rh-8, 2, 10);
  ctx.fillRect(cx-4, cy-rh-6, 8, 2);
  ctx.fillStyle = oldFill;
}

function drawDome(ctx, cx, cy, rw, rh) {
  ctx.beginPath();
  ctx.moveTo(cx - rw, cy);
  ctx.quadraticCurveTo(cx - rw, cy - rh*1.5, cx, cy - rh);
  ctx.quadraticCurveTo(cx + rw, cy - rh*1.5, cx + rw, cy);
  ctx.closePath(); ctx.fill();
}

function drawTree(ctx, x, y, h, type) {
  ctx.fillStyle = "#3a2a1a"; ctx.fillRect(x-2, y-h*0.3, 4, h*0.3);
  if (type === 'pine') {
    ctx.fillStyle = "#2a5a2a";
    for (let i = 0; i < 3; i++) {
      const ly = y - h*0.3 - i*h*0.22;
      const lw = h*0.25 - i*5;
      ctx.beginPath(); ctx.moveTo(x-lw, ly); ctx.lineTo(x, ly-h*0.25); ctx.lineTo(x+lw, ly); ctx.fill();
    }
  } else {
    ctx.fillStyle = "#3a7a3a";
    ctx.beginPath(); ctx.arc(x, y-h*0.55, h*0.28, 0, Math.PI*2); ctx.fill();
    ctx.fillStyle = "#2a6a2a";
    ctx.beginPath(); ctx.arc(x-h*0.1, y-h*0.6, h*0.18, 0, Math.PI*2); ctx.fill();
  }
}

function drawWindow(ctx, x, y, w, h, lit) {
  ctx.fillStyle = lit ? "#e8d080" : "#4a5a6a";
  ctx.fillRect(x, y, w, h);
  ctx.strokeStyle = "#2a2a2a"; ctx.lineWidth = 0.5;
  ctx.strokeRect(x, y, w, h);
  ctx.beginPath(); ctx.moveTo(x+w/2, y); ctx.lineTo(x+w/2, y+h); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(x, y+h/2); ctx.lineTo(x+w, y+h/2); ctx.stroke();
}

function drawCloud(ctx, cx, cy, r) {
  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, Math.PI*2);
  ctx.arc(cx+r*0.8, cy-r*0.3, r*0.7, 0, Math.PI*2);
  ctx.arc(cx-r*0.6, cy-r*0.2, r*0.6, 0, Math.PI*2);
  ctx.arc(cx+r*0.3, cy-r*0.5, r*0.5, 0, Math.PI*2);
  ctx.fill();
}

function drawBirds(ctx, x, y, count) {
  ctx.strokeStyle = "#2a2a3a"; ctx.lineWidth = 1;
  for (let i = 0; i < count; i++) {
    const bx = x + i*18 + Math.sin(i*3)*8;
    const by = y + Math.cos(i*2)*6;
    ctx.beginPath(); ctx.moveTo(bx-5, by+2); ctx.quadraticCurveTo(bx, by-3, bx+5, by+2); ctx.stroke();
  }
}


// 30 Famous Soviet Union Cities
const CITIES = [
  {
    name: "Москва", nameEn: "Moscow",
    image: "", wiki: "https://en.wikipedia.org/wiki/Moscow",
    colors: { sky: "#2a1a3a", ground: "#4a4a3a", accent: "#c44" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      // Clouds
      ctx.fillStyle = "rgba(180,160,140,0.15)"; drawCloud(ctx, w*0.15, h*0.12, 25); drawCloud(ctx, w*0.7, h*0.08, 20);
      // Birds
      drawBirds(ctx, w*0.6, h*0.15, 4);
      // Background buildings (distant Moscow skyline)
      ctx.fillStyle = "#5a4a5a";
      for (let i=0;i<12;i++) { const bh=20+Math.sin(i*1.7)*15; ctx.fillRect(w*0.02+i*w*0.08, g-bh-10, w*0.06, bh+10); }
      // Kremlin wall with crenellations
      ctx.fillStyle = "#8b2020"; ctx.fillRect(w*0.1, g-55, w*0.8, 55);
      ctx.fillStyle = "#7a1818";
      for (let i=0;i<20;i++) ctx.fillRect(w*0.1+i*w*0.04, g-62, w*0.025, 10);
      // Kremlin towers with detailed tops
      ctx.fillStyle = "#a03030";
      [[0.12,85],[0.28,95],[0.5,110],[0.72,95],[0.88,85]].forEach(([x,ht]) => {
        ctx.fillRect(w*x-14, g-ht, 28, ht);
        // Tower details - windows
        ctx.fillStyle = "#6a1818"; ctx.fillRect(w*x-8, g-ht+15, 6, 10); ctx.fillRect(w*x+2, g-ht+15, 6, 10);
        ctx.fillRect(w*x-6, g-ht+35, 12, 8);
        // Green tent roof
        ctx.fillStyle = "#2a8a2a";
        ctx.beginPath(); ctx.moveTo(w*x-16, g-ht); ctx.lineTo(w*x, g-ht-35); ctx.lineTo(w*x+16, g-ht); ctx.fill();
        // Spire
        ctx.fillStyle = "#c8a830"; ctx.fillRect(w*x-1, g-ht-42, 2, 10);
        ctx.fillStyle = "#c44"; drawStar(ctx, w*x, g-ht-30, 7);
        ctx.fillStyle = "#a03030";
      });
      // St Basil's Cathedral - 9 domes
      const bx = w*0.5;
      ctx.fillStyle = "#e8d8c0"; ctx.fillRect(bx-30, g-80, 60, 25);
      // Central dome
      ctx.fillStyle = "#c44"; drawOnionDome(ctx, bx, g-125, 20, 28);
      // Surrounding domes with stripes
      const domes = [[-30,-105,16,22,"#2266aa"],[-18,-115,14,20,"#ddaa22"],[18,-115,14,20,"#44aa44"],[30,-105,16,22,"#aa44aa"],
                     [-22,-95,10,14,"#c44"],[22,-95,10,14,"#2266aa"],[-10,-100,8,12,"#44aa44"],[10,-100,8,12,"#ddaa22"]];
      domes.forEach(([dx,dy,rw,rh,c]) => { ctx.fillStyle = c; drawOnionDome(ctx, bx+dx, g+dy, rw, rh); });
      // GUM building
      ctx.fillStyle = "#d0c0a0"; ctx.fillRect(w*0.15, g-45, w*0.18, 35);
      for (let i=0;i<4;i++) { ctx.fillStyle = "#b0a080"; ctx.fillRect(w*0.16+i*w*0.04, g-40, 8, 25); }
      ctx.fillStyle = "#8a2020"; ctx.fillRect(w*0.15, g-48, w*0.18, 5);
      // Trees along the wall
      for (let i=0;i<6;i++) drawTree(ctx, w*0.05+i*w*0.03, g, 30, 'round');
      // Spasskaya Tower clock face
      ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(w*0.5, g-85, 6, 0, Math.PI*2); ctx.fill();
      ctx.fillStyle = "#222"; ctx.beginPath(); ctx.arc(w*0.5, g-85, 5, 0, Math.PI*2); ctx.fill();
      ctx.strokeStyle = "#c8a830"; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(w*0.5, g-85); ctx.lineTo(w*0.5, g-89); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(w*0.5, g-85); ctx.lineTo(w*0.5+3, g-84); ctx.stroke();
    },
    trivia: [
      "Moscow's metro system opened in 1935 and is one of the deepest in the world.",
      "The Kremlin walls stretch over 2 kilometers in total length.",
      "Moscow was founded in 1147 by Yuri Dolgorukiy.",
      "St Basil's Cathedral has 9 chapels, each with its own unique dome.",
      "Moscow's population exceeded 10 million during the Soviet era."
    ],
    famousPeople: [
      { name: "Антон Чехов", nameEn: "Anton Chekhov", fame: "Playwright and short story writer, master of modern drama and realism.", wiki: "https://en.wikipedia.org/wiki/Anton_Chekhov" },
      { name: "Андрей Сахаров", nameEn: "Andrei Sakharov", fame: "Nuclear physicist and Nobel Peace Prize laureate, father of the Soviet hydrogen bomb turned dissident.", wiki: "https://en.wikipedia.org/wiki/Andrei_Sakharov" },
      { name: "Владимир Маяковский", nameEn: "Vladimir Mayakovsky", fame: "Futurist poet and playwright, voice of the Russian Revolution.", wiki: "https://en.wikipedia.org/wiki/Vladimir_Mayakovsky" }
    ]
  },
  {
    name: "Ленинград", nameEn: "Leningrad",
    image: "", wiki: "https://en.wikipedia.org/wiki/Saint_Petersburg",
    colors: { sky: "#1a2a3a", ground: "#5a5a4a", accent: "#4a90b0" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      drawBirds(ctx, w*0.3, h*0.1, 5);
      ctx.fillStyle = "rgba(160,180,200,0.12)"; drawCloud(ctx, w*0.2, h*0.08, 30); drawCloud(ctx, w*0.8, h*0.15, 22);
      // Neva River
      ctx.fillStyle = "#3a6a8a"; ctx.fillRect(0, g-12, w, 24);
      ctx.fillStyle = "rgba(100,160,200,0.15)";
      for (let i=0;i<15;i++) ctx.fillRect(i*w/15, g-8+Math.sin(i)*3, w/15-2, 2);
      // Bridge
      ctx.fillStyle = "#6a7a8a"; ctx.fillRect(w*0.35, g-16, w*0.3, 6);
      ctx.fillStyle = "#5a6a7a";
      for (let i=0;i<4;i++) ctx.fillRect(w*0.37+i*w*0.07, g-16, 3, 20);
      // Winter Palace / Hermitage
      ctx.fillStyle = "#4a9a7a"; ctx.fillRect(w*0.05, g-75, w*0.38, 63);
      ctx.fillStyle = "#3a8a6a";
      for (let i=0;i<8;i++) { ctx.fillRect(w*0.07+i*w*0.045, g-70, 6, 48); }
      // Windows
      for (let i=0;i<7;i++) { drawWindow(ctx, w*0.075+i*w*0.045+8, g-65, 8, 10, i%3===0); drawWindow(ctx, w*0.075+i*w*0.045+8, g-45, 8, 10, i%2===0); }
      ctx.fillStyle = "#5aaa8a"; ctx.fillRect(w*0.05, g-78, w*0.38, 5);
      // Admiralty spire
      ctx.fillStyle = "#c8a830"; ctx.fillRect(w*0.65-4, g-140, 8, 128);
      ctx.fillStyle = "#e8d8a0"; ctx.fillRect(w*0.65-20, g-50, 40, 38);
      ctx.beginPath(); ctx.moveTo(w*0.65-6, g-140); ctx.lineTo(w*0.65, g-165); ctx.lineTo(w*0.65+6, g-140); ctx.fill();
      // Ship weathervane
      ctx.fillStyle = "#c8a830";
      ctx.beginPath(); ctx.moveTo(w*0.65-3, g-163); ctx.lineTo(w*0.65+5, g-166); ctx.lineTo(w*0.65-3, g-168); ctx.fill();
      // Peter and Paul Fortress
      ctx.fillStyle = "#e8d8a0"; ctx.fillRect(w*0.78, g-60, w*0.18, 48);
      ctx.fillStyle = "#c8a830"; ctx.fillRect(w*0.86, g-110, 5, 60);
      ctx.beginPath(); ctx.moveTo(w*0.86, g-110); ctx.lineTo(w*0.885, g-130); ctx.lineTo(w*0.91, g-110); ctx.fill();
      // Angel on top
      ctx.fillStyle = "#c8a830"; ctx.beginPath(); ctx.arc(w*0.885, g-132, 3, 0, Math.PI*2); ctx.fill();
      // Rostral columns
      ctx.fillStyle = "#a05030";
      [w*0.48, w*0.55].forEach(cx => {
        ctx.fillRect(cx-3, g-70, 6, 58);
        ctx.fillStyle = "#c44";
        ctx.beginPath(); ctx.moveTo(cx-5, g-70); ctx.lineTo(cx, g-80); ctx.lineTo(cx+5, g-70); ctx.fill();
        ctx.fillStyle = "#a05030";
      });
      // Trees
      for (let i=0;i<4;i++) drawTree(ctx, w*0.46+i*12, g, 25, 'round');
    },
    trivia: [
      "Leningrad survived a 872-day siege during WWII, one of history's longest.",
      "The Hermitage Museum holds over 3 million items in its collection.",
      "The city was built on 42 islands connected by over 300 bridges.",
      "Peter the Great founded the city in 1703 as Russia's window to Europe.",
      "During the siege, citizens ate wallpaper paste and leather belts to survive."
    ],
    famousPeople: [
      { name: "Дмитрий Шостакович", nameEn: "Dmitri Shostakovich", fame: "Composer of 15 symphonies, one of the most performed composers of the 20th century.", wiki: "https://en.wikipedia.org/wiki/Dmitri_Shostakovich" },
      { name: "Владимир Путин", nameEn: "Vladimir Putin", fame: "President of Russia, former KGB officer born in Leningrad.", wiki: "https://en.wikipedia.org/wiki/Vladimir_Putin" },
      { name: "Александр Блок", nameEn: "Alexander Blok", fame: "Symbolist poet, considered one of the greatest Russian poets of the 20th century.", wiki: "https://en.wikipedia.org/wiki/Alexander_Blok" }
    ]
  },
  {
    name: "Киев", nameEn: "Kiev",
    image: "", wiki: "https://en.wikipedia.org/wiki/Kyiv",
    colors: { sky: "#2a2a4a", ground: "#5a6a3a", accent: "#c8a830" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      drawBirds(ctx, w*0.5, h*0.12, 3);
      // Dnieper River
      ctx.fillStyle = "#3a5a8a"; ctx.fillRect(0, g-8, w, 18);
      ctx.fillStyle = "rgba(80,140,200,0.12)";
      for (let i=0;i<12;i++) ctx.fillRect(i*w/12, g-4+Math.sin(i*0.8)*2, w/12-3, 2);
      // Distant hills
      ctx.fillStyle = "#4a5a3a";
      ctx.beginPath(); ctx.moveTo(0,g-8); ctx.quadraticCurveTo(w*0.3,g-40,w*0.6,g-15); ctx.quadraticCurveTo(w*0.8,g-30,w,g-8); ctx.lineTo(w,g-8); ctx.fill();
      // Kyiv Pechersk Lavra - golden domes
      ctx.fillStyle = "#e8d8a0"; ctx.fillRect(w*0.2, g-75, w*0.35, 63);
      for (let i=0;i<6;i++) drawWindow(ctx, w*0.22+i*w*0.05, g-65, 7, 10, i%2===0);
      ctx.fillStyle = "#fff";
      drawOnionDome(ctx, w*0.28, g-105, 14, 20);
      drawOnionDome(ctx, w*0.37, g-120, 18, 26);
      drawOnionDome(ctx, w*0.46, g-105, 14, 20);
      // Bell tower
      ctx.fillStyle = "#e8d8a0"; ctx.fillRect(w*0.37-8, g-90, 16, 15);
      ctx.fillStyle = "#d0c090"; ctx.fillRect(w*0.37-6, g-75, 12, 10);
      // Motherland Monument
      ctx.fillStyle = "#c0c0c0"; ctx.fillRect(w*0.72-3, g-140, 6, 100);
      ctx.beginPath(); ctx.moveTo(w*0.68, g-40); ctx.lineTo(w*0.72, g-140); ctx.lineTo(w*0.76, g-40); ctx.fill();
      // Shield
      ctx.fillStyle = "#c0c0b0"; ctx.fillRect(w*0.72-8, g-120, 16, 20);
      // Sword arm
      ctx.save(); ctx.translate(w*0.75, g-135); ctx.rotate(-0.5);
      ctx.fillRect(-1, -35, 3, 35); ctx.restore();
      // Trees
      for (let i=0;i<5;i++) drawTree(ctx, w*0.6+i*15, g, 28, 'round');
      for (let i=0;i<3;i++) drawTree(ctx, w*0.08+i*12, g, 22, 'round');
    },
    trivia: [
      "Kyiv is one of the oldest cities in Eastern Europe, founded around the 5th century.",
      "The Kyiv Metro's Arsenalna station is the deepest in the world at 105.5 meters.",
      "The Motherland Monument stands 102 meters tall including its base.",
      "Kyiv Pechersk Lavra monastery dates back to 1051 AD.",
      "The city sits on the banks of the Dnieper, Europe's fourth-longest river."
    ],
    famousPeople: [
      { name: "Михаил Булгаков", nameEn: "Mikhail Bulgakov", fame: "Author of 'The Master and Margarita', one of the greatest novels of the 20th century.", wiki: "https://en.wikipedia.org/wiki/Mikhail_Bulgakov" },
      { name: "Казимир Малевич", nameEn: "Kazimir Malevich", fame: "Pioneer of geometric abstract art and creator of the Suprematist movement.", wiki: "https://en.wikipedia.org/wiki/Kazimir_Malevich" },
      { name: "Голда Меир", nameEn: "Golda Meir", fame: "Fourth Prime Minister of Israel, born in Kiev in 1898.", wiki: "https://en.wikipedia.org/wiki/Golda_Meir" }
    ]
  },
  {
    name: "Минск", nameEn: "Minsk",
    image: "", wiki: "https://en.wikipedia.org/wiki/Minsk",
    colors: { sky: "#2a2a3a", ground: "#4a5a3a", accent: "#6a9a50" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      ctx.fillStyle = "rgba(150,170,150,0.1)"; drawCloud(ctx, w*0.6, h*0.1, 28);
      // Background Soviet apartment blocks
      ctx.fillStyle = "#6a6a6a";
      for (let i=0;i<8;i++) { const bh=30+i*5; ctx.fillRect(w*0.02+i*w*0.12, g-bh, w*0.1, bh);
        for (let j=0;j<3;j++) for (let k=0;k<2;k++) drawWindow(ctx, w*0.03+i*w*0.12+j*12, g-bh+8+k*12, 5, 6, (i+j+k)%3===0);
      }
      // National Library (diamond shape)
      ctx.fillStyle = "#4a7a9a";
      ctx.beginPath(); ctx.moveTo(w*0.5, g-130); ctx.lineTo(w*0.58, g-75); ctx.lineTo(w*0.5, g-20); ctx.lineTo(w*0.42, g-75); ctx.fill();
      ctx.strokeStyle = "#6a9aba"; ctx.lineWidth = 0.8;
      for (let i=0;i<8;i++) { ctx.beginPath(); ctx.moveTo(w*0.42+i*2.5, g-75-i*7); ctx.lineTo(w*0.58-i*2.5, g-75-i*7); ctx.stroke(); }
      for (let i=0;i<8;i++) { ctx.beginPath(); ctx.moveTo(w*0.42+i*2.5, g-75+i*7); ctx.lineTo(w*0.58-i*2.5, g-75+i*7); ctx.stroke(); }
      // LED panels on library
      ctx.fillStyle = "rgba(100,200,255,0.15)";
      ctx.fillRect(w*0.46, g-100, w*0.08, 50);
      // Victory obelisk
      ctx.fillStyle = "#c0c0c0"; ctx.fillRect(w*0.25-3, g-110, 6, 110);
      ctx.fillStyle = "#c44"; drawStar(ctx, w*0.25, g-115, 9);
      ctx.fillStyle = "#aaa"; ctx.fillRect(w*0.25-10, g-8, 20, 8);
      // Independence Avenue buildings
      ctx.fillStyle = "#8a7a6a"; ctx.fillRect(w*0.65, g-65, w*0.28, 65);
      ctx.fillStyle = "#7a6a5a";
      for (let i=0;i<5;i++) ctx.fillRect(w*0.67+i*w*0.05, g-60, 8, 40);
      for (let i=0;i<5;i++) drawWindow(ctx, w*0.67+i*w*0.05, g-55, 8, 10, i%2===0);
      ctx.fillStyle = "#6a5a4a"; ctx.fillRect(w*0.65, g-68, w*0.28, 5);
      // Trees
      for (let i=0;i<4;i++) drawTree(ctx, w*0.12+i*18, g, 24, 'round');
    },
    trivia: [
      "Minsk was almost completely destroyed during WWII and rebuilt in Soviet style.",
      "The National Library of Belarus has a unique rhombicuboctahedron shape.",
      "Minsk hosted the 1980 Olympic football matches.",
      "The city's population grew from 100,000 in 1939 to over 1.5 million by 1989.",
      "Independence Avenue in Minsk stretches 15 km, one of Europe's longest streets."
    ],
    famousPeople: [
      { name: "Марк Шагал", nameEn: "Marc Chagall", fame: "Modernist painter known for dreamlike, fantastical imagery. Born in Vitebsk, studied in Minsk.", wiki: "https://en.wikipedia.org/wiki/Marc_Chagall" },
      { name: "Ли Харви Освальд", nameEn: "Lee Harvey Oswald", fame: "Lived in Minsk 1960-62 while defecting to the USSR. Assassin of President Kennedy.", wiki: "https://en.wikipedia.org/wiki/Lee_Harvey_Oswald" },
      { name: "Светлана Алексиевич", nameEn: "Svetlana Alexievich", fame: "Nobel Prize in Literature (2015), journalist and author of oral histories.", wiki: "https://en.wikipedia.org/wiki/Svetlana_Alexievich" }
    ]
  },
  {
    name: "Тбилиси", nameEn: "Tbilisi",
    image: "", wiki: "https://en.wikipedia.org/wiki/Tbilisi",
    colors: { sky: "#3a2a2a", ground: "#6a5a3a", accent: "#c08040" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      drawBirds(ctx, w*0.7, h*0.08, 3);
      // Mountains
      ctx.fillStyle = "#5a4a3a";
      ctx.beginPath(); ctx.moveTo(0, g-30); ctx.lineTo(w*0.15, g-90); ctx.lineTo(w*0.3, g-50); ctx.lineTo(w*0.5, g-110);
      ctx.lineTo(w*0.65, g-60); ctx.lineTo(w*0.8, g-95); ctx.lineTo(w, g-40); ctx.lineTo(w, g); ctx.lineTo(0, g); ctx.fill();
      // Mtkvari River
      ctx.fillStyle = "#4a7a6a"; ctx.fillRect(0, g-15, w, 15);
      // Narikala Fortress on hill
      ctx.fillStyle = "#8a6a4a"; ctx.fillRect(w*0.55, g-115, 45, 75);
      ctx.fillStyle = "#7a5a3a";
      for (let i=0;i<4;i++) ctx.fillRect(w*0.55+i*12, g-120, 8, 5);
      ctx.fillRect(w*0.52, g-100, 8, 60); ctx.fillRect(w*0.62, g-105, 8, 65);
      // Fortress tower
      ctx.fillRect(w*0.57, g-130, 12, 20);
      ctx.fillStyle = "#6a4a2a";
      for (let i=0;i<3;i++) ctx.fillRect(w*0.575+i*3, g-132, 2, 4);
      // Metekhi Church
      ctx.fillStyle = "#e8d8a0"; ctx.fillRect(w*0.25, g-85, 35, 55);
      ctx.fillStyle = "#c8a830"; drawOnionDome(ctx, w*0.25+17, g-95, 14, 20);
      for (let i=0;i<3;i++) drawWindow(ctx, w*0.27+i*9, g-75, 5, 8, true);
      // Old town colorful houses
      const hc = ["#c06040","#d4a060","#80a060","#6080a0","#a06080","#c0a050"];
      for (let i=0;i<6;i++) {
        ctx.fillStyle = hc[i]; ctx.fillRect(w*0.02+i*w*0.065, g-45-i*4, w*0.055, 45+i*4);
        // Balconies
        ctx.fillStyle = "#5a3a2a"; ctx.fillRect(w*0.025+i*w*0.065, g-30-i*4, w*0.045, 3);
        for (let j=0;j<2;j++) drawWindow(ctx, w*0.025+i*w*0.065+j*10, g-42-i*4, 6, 8, (i+j)%2===0);
      }
      // Sulfur bath domes
      ctx.fillStyle = "#a08060";
      drawDome(ctx, w*0.78, g-30, 14, 10);
      drawDome(ctx, w*0.85, g-25, 12, 8);
      drawDome(ctx, w*0.92, g-28, 10, 7);
      // Bridge of Peace (modern glass)
      ctx.strokeStyle = "#8ac0c0"; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(w*0.3, g-18); ctx.quadraticCurveTo(w*0.45, g-35, w*0.6, g-18); ctx.stroke();
      ctx.fillStyle = "rgba(140,200,200,0.2)";
      ctx.beginPath(); ctx.moveTo(w*0.3, g-18); ctx.quadraticCurveTo(w*0.45, g-35, w*0.6, g-18); ctx.lineTo(w*0.6, g-12); ctx.quadraticCurveTo(w*0.45, g-28, w*0.3, g-12); ctx.fill();
    },
    trivia: [
      "Tbilisi was founded in the 5th century near natural hot springs.",
      "The name Tbilisi comes from 'tbili' meaning 'warm' in Georgian.",
      "Narikala Fortress dates back to the 4th century AD.",
      "Tbilisi's sulfur baths have been in use for over 700 years.",
      "The city sits in a valley surrounded by mountains on three sides."
    ],
    famousPeople: [
      { name: "Нико Пиросмани", nameEn: "Niko Pirosmani", fame: "Self-taught primitivist painter, one of Georgia's most beloved artists.", wiki: "https://en.wikipedia.org/wiki/Niko_Pirosmani" },
      { name: "Георгий Данелия", nameEn: "Georgy Daneliya", fame: "Film director of beloved Soviet comedies like 'Mimino' and 'Kin-dza-dza!'.", wiki: "https://en.wikipedia.org/wiki/Georgy_Daneliya" },
      { name: "Шота Руставели", nameEn: "Shota Rustaveli", fame: "Medieval poet, author of 'The Knight in the Panther's Skin', Georgia's national epic.", wiki: "https://en.wikipedia.org/wiki/Shota_Rustaveli" }
    ]
  },
  {
    name: "Баку", nameEn: "Baku",
    image: "", wiki: "https://en.wikipedia.org/wiki/Baku",
    colors: { sky: "#3a2a1a", ground: "#8a7a5a", accent: "#d4a853" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      ctx.fillStyle = "rgba(200,180,140,0.1)"; drawCloud(ctx, w*0.3, h*0.1, 22);
      // Caspian Sea
      ctx.fillStyle = "#2a5a7a"; ctx.fillRect(w*0.55, g-12, w*0.45, 24);
      ctx.fillStyle = "rgba(60,120,180,0.1)";
      for (let i=0;i<8;i++) ctx.fillRect(w*0.57+i*w*0.05, g-6+Math.sin(i)*2, w*0.04, 2);
      // Flame Towers
      ctx.fillStyle = "#4a7aaa";
      [[0.28,140],[0.36,155],[0.44,142]].forEach(([x,ht]) => {
        ctx.beginPath(); ctx.moveTo(w*x-12, g); ctx.quadraticCurveTo(w*x-14, g-ht*0.7, w*x, g-ht);
        ctx.quadraticCurveTo(w*x+14, g-ht*0.7, w*x+12, g); ctx.fill();
        // Glass panels
        ctx.strokeStyle = "rgba(100,180,255,0.3)"; ctx.lineWidth = 0.5;
        for (let i=1;i<8;i++) { const py=g-ht*i/8; ctx.beginPath(); ctx.moveTo(w*x-10+i, py); ctx.lineTo(w*x+10-i, py); ctx.stroke(); }
      });
      // Maiden Tower
      ctx.fillStyle = "#c8b080"; ctx.fillRect(w*0.68-10, g-90, 20, 90);
      ctx.fillStyle = "#b0a070"; ctx.fillRect(w*0.68-12, g-95, 24, 8);
      ctx.fillRect(w*0.68-12, g-70, 24, 4);
      ctx.fillRect(w*0.68-12, g-45, 24, 4);
      // Crenellations
      for (let i=0;i<5;i++) ctx.fillRect(w*0.68-10+i*5, g-98, 3, 5);
      // Old City walls
      ctx.fillStyle = "#a09070"; ctx.fillRect(w*0.55, g-35, w*0.4, 23);
      ctx.fillStyle = "#8a7a60";
      for (let i=0;i<8;i++) ctx.fillRect(w*0.56+i*w*0.05, g-38, 3, 5);
      // Oil derricks in distance
      ctx.fillStyle = "#555";
      for (let i=0;i<3;i++) {
        const dx = w*0.08+i*w*0.06;
        ctx.fillRect(dx, g-50, 2, 40);
        ctx.beginPath(); ctx.moveTo(dx-6, g-10); ctx.lineTo(dx+1, g-50); ctx.lineTo(dx+8, g-10); ctx.stroke();
      }
      // Trees
      for (let i=0;i<3;i++) drawTree(ctx, w*0.5+i*12, g, 20, 'round');
    },
    trivia: [
      "Baku is known as the 'City of Winds' due to its strong Caspian breezes.",
      "The Maiden Tower is a UNESCO World Heritage Site dating to the 12th century.",
      "Baku's oil boom in the 1890s made it one of the world's wealthiest cities.",
      "The Flame Towers are 182 meters tall and shaped like flames.",
      "Baku hosted the first ever Formula 1 Azerbaijan Grand Prix in 2017."
    ],
    famousPeople: [
      { name: "Муслим Магомаев", nameEn: "Muslim Magomayev", fame: "Legendary Soviet-era singer, the 'Soviet Sinatra', beloved across the USSR.", wiki: "https://en.wikipedia.org/wiki/Muslim_Magomayev_(musician)" },
      { name: "Лев Ландау", nameEn: "Lev Landau", fame: "Nobel Prize-winning physicist, pioneer of theoretical physics in the Soviet Union.", wiki: "https://en.wikipedia.org/wiki/Lev_Landau" },
      { name: "Рихард Зорге", nameEn: "Richard Sorge", fame: "Soviet spy in WWII, born in Baku, considered one of the greatest spies in history.", wiki: "https://en.wikipedia.org/wiki/Richard_Sorge" }
    ]
  },
  {
    name: "Ереван", nameEn: "Yerevan",
    image: "", wiki: "https://en.wikipedia.org/wiki/Yerevan",
    colors: { sky: "#3a2a3a", ground: "#7a5a4a", accent: "#d08050" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      // Mount Ararat (twin peaks)
      ctx.fillStyle = "#8a7a8a";
      ctx.beginPath(); ctx.moveTo(w*0.3, g-20); ctx.lineTo(w*0.5, g-150); ctx.lineTo(w*0.7, g-20); ctx.fill();
      ctx.beginPath(); ctx.moveTo(w*0.55, g-20); ctx.lineTo(w*0.68, g-110); ctx.lineTo(w*0.82, g-20); ctx.fill();
      // Snow caps
      ctx.fillStyle = "#fff";
      ctx.beginPath(); ctx.moveTo(w*0.5, g-150); ctx.lineTo(w*0.44, g-120); ctx.lineTo(w*0.56, g-120); ctx.fill();
      ctx.beginPath(); ctx.moveTo(w*0.68, g-110); ctx.lineTo(w*0.64, g-90); ctx.lineTo(w*0.72, g-90); ctx.fill();
      // The Cascade
      ctx.fillStyle = "#e0d0b0";
      for (let i=0;i<7;i++) ctx.fillRect(w*0.12+i*3, g-15-i*12, w*0.18-i*4, 12);
      ctx.fillStyle = "#c0b090";
      for (let i=0;i<7;i++) ctx.fillRect(w*0.13+i*3, g-13-i*12, 4, 8);
      // Republic Square (pink tuff buildings)
      ctx.fillStyle = "#c08060"; ctx.fillRect(w*0.35, g-60, w*0.25, 48);
      ctx.fillStyle = "#b07050";
      for (let i=0;i<5;i++) ctx.fillRect(w*0.36+i*w*0.045, g-55, 6, 35);
      for (let i=0;i<4;i++) drawWindow(ctx, w*0.37+i*w*0.05, g-50, 6, 8, i%2===0);
      ctx.fillStyle = "#a06040"; ctx.fillRect(w*0.35, g-63, w*0.25, 5);
      // Arched entrance
      ctx.fillStyle = "#6a3a2a";
      ctx.beginPath(); ctx.arc(w*0.475, g-20, 10, Math.PI, 0); ctx.fill();
      ctx.fillRect(w*0.465, g-20, 20, 8);
      // Opera House
      ctx.fillStyle = "#d0a080"; ctx.fillRect(w*0.65, g-55, w*0.2, 43);
      ctx.fillStyle = "#c09070"; drawDome(ctx, w*0.75, g-60, 18, 14);
      for (let i=0;i<3;i++) ctx.fillRect(w*0.67+i*w*0.06, g-50, 5, 30);
      // Genocide Memorial
      ctx.fillStyle = "#808080";
      ctx.beginPath(); ctx.moveTo(w*0.9, g-80); ctx.lineTo(w*0.92, g); ctx.lineTo(w*0.88, g); ctx.fill();
      // Trees
      for (let i=0;i<5;i++) drawTree(ctx, w*0.3+i*14, g, 22, 'round');
    },
    trivia: [
      "Yerevan is one of the world's oldest continuously inhabited cities, founded in 782 BC.",
      "The city is built from pink volcanic tuff, earning it the nickname 'Pink City'.",
      "Mount Ararat, visible from Yerevan, is where Noah's Ark supposedly landed.",
      "The Cascade is a giant stairway with art galleries built into the hillside.",
      "Armenia was the first country to adopt Christianity as a state religion in 301 AD."
    ],
    famousPeople: [
      { name: "Арам Хачатурян", nameEn: "Aram Khachaturian", fame: "Composer of 'Sabre Dance' and the ballet 'Spartacus', one of the great Soviet composers.", wiki: "https://en.wikipedia.org/wiki/Aram_Khachaturian" },
      { name: "Шарль Азнавур", nameEn: "Charles Aznavour", fame: "French-Armenian singer and actor, one of the best-selling artists in history.", wiki: "https://en.wikipedia.org/wiki/Charles_Aznavour" },
      { name: "Сергей Параджанов", nameEn: "Sergei Parajanov", fame: "Avant-garde filmmaker, director of 'The Color of Pomegranates'.", wiki: "https://en.wikipedia.org/wiki/Sergei_Parajanov" }
    ]
  },
  {
    name: "Ташкент", nameEn: "Tashkent",
    image: "", wiki: "https://en.wikipedia.org/wiki/Tashkent",
    colors: { sky: "#3a3a1a", ground: "#9a8a5a", accent: "#4a9a7a" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      ctx.fillStyle = "rgba(200,200,150,0.08)"; drawCloud(ctx, w*0.5, h*0.08, 25);
      // Chorsu Bazaar dome
      ctx.fillStyle = "#4a9a9a"; drawDome(ctx, w*0.18, g-55, 30, 22);
      ctx.fillStyle = "#e8d8a0"; ctx.fillRect(w*0.05, g-35, w*0.26, 23);
      ctx.fillStyle = "#d0c090";
      for (let i=0;i<5;i++) { ctx.beginPath(); ctx.arc(w*0.07+i*w*0.05, g-35, 8, Math.PI, 0); ctx.fill(); }
      // Khast Imam complex
      ctx.fillStyle = "#e8d8a0"; ctx.fillRect(w*0.35, g-70, w*0.2, 58);
      ctx.fillStyle = "#4a9a9a"; drawOnionDome(ctx, w*0.45, g-105, 22, 30);
      for (let i=0;i<4;i++) drawWindow(ctx, w*0.37+i*w*0.04, g-60, 6, 10, i%2===0);
      // Minarets
      ctx.fillStyle = "#c8b890"; ctx.fillRect(w*0.33, g-115, 5, 103); ctx.fillRect(w*0.57, g-115, 5, 103);
      ctx.fillStyle = "#4a9a9a";
      drawDome(ctx, w*0.335, g-118, 4, 5); drawDome(ctx, w*0.575, g-118, 4, 5);
      // Balconies on minarets
      ctx.fillStyle = "#c8b890";
      ctx.fillRect(w*0.33-3, g-90, 11, 3); ctx.fillRect(w*0.57-3, g-90, 11, 3);
      // TV Tower
      ctx.fillStyle = "#c0c0c0"; ctx.fillRect(w*0.75-2, g-150, 4, 150);
      ctx.fillStyle = "#aaa"; ctx.beginPath(); ctx.arc(w*0.75, g-110, 12, 0, Math.PI*2); ctx.fill();
      ctx.fillStyle = "#999"; ctx.beginPath(); ctx.arc(w*0.75, g-100, 8, 0, Math.PI*2); ctx.fill();
      ctx.fillStyle = "#c44"; ctx.beginPath(); ctx.arc(w*0.75, g-152, 2, 0, Math.PI*2); ctx.fill();
      // Earthquake monument
      ctx.fillStyle = "#808080"; ctx.fillRect(w*0.65, g-40, 3, 28);
      ctx.beginPath(); ctx.arc(w*0.665, g-42, 5, 0, Math.PI*2); ctx.fill();
      // Traditional houses
      ctx.fillStyle = "#d4a060"; ctx.fillRect(w*0.82, g-40, w*0.12, 28);
      ctx.fillStyle = "#c09050";
      ctx.beginPath(); ctx.moveTo(w*0.82, g-40); ctx.lineTo(w*0.88, g-55); ctx.lineTo(w*0.94, g-40); ctx.fill();
      // Trees
      for (let i=0;i<3;i++) drawTree(ctx, w*0.62+i*12, g, 20, 'round');
    },
    trivia: [
      "Tashkent was almost completely rebuilt after a massive earthquake in 1966.",
      "The Tashkent Metro opened in 1977, the first in Central Asia.",
      "Tashkent's Chorsu Bazaar has been a trading hub for over 2,000 years.",
      "The city sits at the crossroads of the ancient Silk Road.",
      "Tashkent's TV Tower stands 375 meters tall, the tallest structure in Central Asia."
    ],
    famousPeople: [
      { name: "Ислам Каримов", nameEn: "Islam Karimov", fame: "First President of Uzbekistan, ruled from independence until 2016.", wiki: "https://en.wikipedia.org/wiki/Islam_Karimov" },
      { name: "Шараф Рашидов", nameEn: "Sharaf Rashidov", fame: "First Secretary of the Communist Party of Uzbekistan for 24 years, novelist.", wiki: "https://en.wikipedia.org/wiki/Sharaf_Rashidov" },
      { name: "Тамара Ханум", nameEn: "Tamara Khanum", fame: "Pioneer of Uzbek dance, first Uzbek woman to perform without a veil on stage.", wiki: "https://en.wikipedia.org/wiki/Tamara_Khanum" }
    ]
  },
  {
    name: "Алма-Ата", nameEn: "Alma-Ata",
    image: "", wiki: "https://en.wikipedia.org/wiki/Almaty",
    colors: { sky: "#2a3a4a", ground: "#5a7a4a", accent: "#6aaa6a" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      drawBirds(ctx, w*0.4, h*0.1, 4);
      // Tian Shan mountains (detailed)
      ctx.fillStyle = "#6a7a8a";
      ctx.beginPath(); ctx.moveTo(0, g-15); ctx.lineTo(w*0.1, g-80); ctx.lineTo(w*0.2, g-55); ctx.lineTo(w*0.3, g-100);
      ctx.lineTo(w*0.42, g-65); ctx.lineTo(w*0.5, g-140); ctx.lineTo(w*0.58, g-75); ctx.lineTo(w*0.7, g-110);
      ctx.lineTo(w*0.8, g-130); ctx.lineTo(w*0.9, g-70); ctx.lineTo(w, g-45); ctx.lineTo(w, g); ctx.lineTo(0, g); ctx.fill();
      // Snow caps
      ctx.fillStyle = "#fff";
      [[0.5,-140,-110],[0.8,-130,-105],[0.3,-100,-80]].forEach(([x,top,bot]) => {
        ctx.beginPath(); ctx.moveTo(w*x, g+top); ctx.lineTo(w*(x-0.04), g+bot); ctx.lineTo(w*(x+0.04), g+bot); ctx.fill();
      });
      // Foothills with trees
      ctx.fillStyle = "#4a6a3a";
      ctx.beginPath(); ctx.moveTo(0,g-10); ctx.quadraticCurveTo(w*0.3,g-35,w*0.6,g-15); ctx.quadraticCurveTo(w*0.8,g-25,w,g-10); ctx.lineTo(w,g); ctx.lineTo(0,g); ctx.fill();
      for (let i=0;i<10;i++) drawTree(ctx, w*0.05+i*w*0.09, g-5-Math.sin(i)*5, 18+i%3*4, 'pine');
      // Zenkov Cathedral (wooden, colorful)
      ctx.fillStyle = "#d4a040"; ctx.fillRect(w*0.38, g-75, 35, 50);
      ctx.fillStyle = "#c09030";
      for (let i=0;i<3;i++) drawWindow(ctx, w*0.39+i*10, g-65, 6, 10, true);
      ctx.fillStyle = "#4a8a4a"; drawOnionDome(ctx, w*0.38+17, g-90, 14, 20);
      ctx.fillStyle = "#4a8a4a"; drawOnionDome(ctx, w*0.38+5, g-80, 8, 12);
      ctx.fillStyle = "#4a8a4a"; drawOnionDome(ctx, w*0.38+29, g-80, 8, 12);
      // Medeu skating rink
      ctx.fillStyle = "#8ac0e0"; ctx.fillRect(w*0.12, g-28, w*0.22, 16);
      ctx.strokeStyle = "#fff"; ctx.lineWidth = 0.5; ctx.strokeRect(w*0.12, g-28, w*0.22, 16);
      ctx.fillStyle = "#6aa0c0";
      for (let i=0;i<4;i++) ctx.fillRect(w*0.13+i*w*0.05, g-30, 2, 20);
      // Kok-Tobe TV tower
      ctx.fillStyle = "#aaa"; ctx.fillRect(w*0.72, g-100, 3, 80);
      ctx.fillStyle = "#c44"; ctx.beginPath(); ctx.arc(w*0.735, g-102, 2, 0, Math.PI*2); ctx.fill();
    },
    trivia: [
      "Almaty means 'Father of Apples' — the region is the origin of domestic apples.",
      "The Medeu skating rink sits at 1,691 meters above sea level.",
      "Zenkov Cathedral was built entirely of wood without a single nail.",
      "Almaty was the capital of Kazakhstan until 1997.",
      "The city is surrounded by the Tian Shan mountain range."
    ],
    famousPeople: [
      { name: "Динмухамед Кунаев", nameEn: "Dinmukhamed Kunayev", fame: "First Secretary of the Communist Party of Kazakhstan, member of the Politburo.", wiki: "https://en.wikipedia.org/wiki/Dinmukhamed_Kunayev" },
      { name: "Алия Молдагулова", nameEn: "Aliya Moldagulova", fame: "Soviet sniper in WWII, Hero of the Soviet Union, studied in Alma-Ata.", wiki: "https://en.wikipedia.org/wiki/Aliya_Moldagulova" },
      { name: "Олжас Сулейменов", nameEn: "Olzhas Suleimenov", fame: "Poet and anti-nuclear activist, led the Nevada-Semipalatinsk movement.", wiki: "https://en.wikipedia.org/wiki/Olzhas_Suleimenov" }
    ]
  },
  {
    name: "Самарканд", nameEn: "Samarkand",
    image: "", wiki: "https://en.wikipedia.org/wiki/Samarkand",
    colors: { sky: "#3a3a2a", ground: "#b0a070", accent: "#2a7aaa" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      ctx.fillStyle = "rgba(180,180,140,0.08)"; drawCloud(ctx, w*0.7, h*0.1, 20);
      // Registan Square - three madrasas
      [[0.2,95,"#2a7aaa"],[0.5,110,"#1a6a9a"],[0.8,95,"#2a7aaa"]].forEach(([x,ht,c]) => {
        ctx.fillStyle = c;
        ctx.fillRect(w*x-25, g-ht, 50, ht);
        // Iwan (arched entrance)
        ctx.fillStyle = "#1a5a8a";
        ctx.beginPath(); ctx.arc(w*x, g-ht+30, 15, Math.PI, 0); ctx.fill();
        ctx.fillRect(w*x-15, g-ht+30, 30, 30);
        // Dome
        ctx.fillStyle = c; drawDome(ctx, w*x, g-ht-12, 18, 14);
        // Minarets
        ctx.fillStyle = "#c8b890"; ctx.fillRect(w*x-27, g-ht-18, 5, ht+8); ctx.fillRect(w*x+22, g-ht-18, 5, ht+8);
        // Minaret tops
        ctx.fillStyle = c; drawDome(ctx, w*x-24.5, g-ht-20, 4, 5); drawDome(ctx, w*x+24.5, g-ht-20, 4, 5);
        // Tile patterns
        ctx.fillStyle = "rgba(200,180,100,0.3)";
        for (let i=0;i<3;i++) for (let j=0;j<4;j++) ctx.fillRect(w*x-20+i*14, g-ht+5+j*14, 8, 8);
      });
      // Courtyard
      ctx.fillStyle = "#c8b890"; ctx.fillRect(w*0.25, g-10, w*0.5, 8);
      // Bibi-Khanym Mosque in distance
      ctx.fillStyle = "#3a8aaa"; ctx.globalAlpha = 0.5;
      drawDome(ctx, w*0.05, g-50, 15, 12);
      ctx.fillRect(w*0.02, g-40, 8, 28);
      ctx.globalAlpha = 1;
      // Trees
      for (let i=0;i<3;i++) drawTree(ctx, w*0.35+i*w*0.15, g, 18, 'round');
    },
    trivia: [
      "Samarkand is one of the oldest inhabited cities, dating back to the 7th century BC.",
      "The Registan Square is considered one of the finest examples of Islamic architecture.",
      "Tamerlane made Samarkand the capital of his vast empire in the 14th century.",
      "The city was a major stop on the Silk Road between China and Europe.",
      "Ulugh Beg's observatory in Samarkand was one of the finest in the medieval world."
    ],
    famousPeople: [
      { name: "Тамерлан", nameEn: "Timur (Tamerlane)", fame: "Turco-Mongol conqueror who made Samarkand the capital of his vast empire.", wiki: "https://en.wikipedia.org/wiki/Timur" },
      { name: "Улугбек", nameEn: "Ulugh Beg", fame: "Timurid sultan and astronomer, built one of the greatest medieval observatories.", wiki: "https://en.wikipedia.org/wiki/Ulugh_Beg" },
      { name: "Рудаки", nameEn: "Rudaki", fame: "Father of Persian poetry, lived and worked in Samarkand.", wiki: "https://en.wikipedia.org/wiki/Rudaki" }
    ]
  },
  {
    name: "Новосибирск", nameEn: "Novosibirsk",
    image: "", wiki: "https://en.wikipedia.org/wiki/Novosibirsk",
    colors: { sky: "#1a2a3a", ground: "#4a5a4a", accent: "#7a9ab0" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      ctx.fillStyle = "rgba(140,160,180,0.1)"; drawCloud(ctx, w*0.4, h*0.08, 28);
      // Ob River
      ctx.fillStyle = "#3a5a7a"; ctx.fillRect(0, g-10, w, 20);
      ctx.fillStyle = "rgba(80,140,180,0.1)";
      for (let i=0;i<12;i++) ctx.fillRect(i*w/12, g-5+Math.sin(i)*2, w/12-3, 2);
      // Bridge over Ob
      ctx.fillStyle = "#808080"; ctx.fillRect(w*0.05, g-16, w*0.9, 5);
      for (let i=0;i<12;i++) ctx.fillRect(w*0.05+i*w*0.075, g-16, 3, 18);
      // Opera House (largest in Russia)
      ctx.fillStyle = "#d0c8b0"; ctx.fillRect(w*0.25, g-70, w*0.45, 58);
      ctx.fillStyle = "#b0a890"; drawDome(ctx, w*0.475, g-75, 35, 25);
      for (let i=0;i<8;i++) ctx.fillRect(w*0.27+i*w*0.05, g-65, 5, 45);
      for (let i=0;i<7;i++) drawWindow(ctx, w*0.28+i*w*0.05+6, g-58, 6, 10, i%3===0);
      ctx.fillStyle = "#c0b8a0"; ctx.fillRect(w*0.25, g-73, w*0.45, 5);
      // Entrance columns
      ctx.fillStyle = "#c8c0a0";
      for (let i=0;i<4;i++) ctx.fillRect(w*0.42+i*12, g-65, 4, 50);
      // Akademgorodok buildings
      ctx.fillStyle = "#6a7a6a"; ctx.fillRect(w*0.78, g-50, 22, 38); ctx.fillRect(w*0.83, g-60, 18, 48);
      for (let i=0;i<2;i++) for (let j=0;j<3;j++) drawWindow(ctx, w*0.79+i*6, g-45+j*10, 4, 5, true);
      // Lenin statue
      ctx.fillStyle = "#808080"; ctx.fillRect(w*0.15, g-55, 3, 30);
      ctx.beginPath(); ctx.arc(w*0.165, g-58, 4, 0, Math.PI*2); ctx.fill();
      // Trees
      for (let i=0;i<6;i++) drawTree(ctx, w*0.02+i*w*0.035, g, 22, 'pine');
      for (let i=0;i<3;i++) drawTree(ctx, w*0.73+i*12, g, 20, 'pine');
    },
    trivia: [
      "Novosibirsk is Russia's third-largest city and the largest in Siberia.",
      "The city's opera house is the largest theater building in Russia.",
      "Akademgorodok is a famous scientific research center built in the 1950s.",
      "Novosibirsk grew from a small village to a major city in just 70 years.",
      "The Trans-Siberian Railway passes through Novosibirsk."
    ],
    famousPeople: [
      { name: "Александр Покрышкин", nameEn: "Alexander Pokryshkin", fame: "WWII triple Hero of the Soviet Union, top Soviet fighter ace.", wiki: "https://en.wikipedia.org/wiki/Alexander_Pokryshkin" },
      { name: "Кондратий Рылеев", nameEn: "Kondratiy Ryleyev", fame: "Decembrist poet and revolutionary, exiled to Siberia.", wiki: "https://en.wikipedia.org/wiki/Kondratiy_Ryleyev" }
    ]
  },
  {
    name: "Сталинград", nameEn: "Stalingrad",
    image: "", wiki: "https://en.wikipedia.org/wiki/Volgograd",
    colors: { sky: "#2a2a3a", ground: "#6a5a4a", accent: "#c44" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      // Volga river
      ctx.fillStyle = "#3a5a7a"; ctx.fillRect(0, g-10, w, 20);
      // Mamayev Kurgan hill
      ctx.fillStyle = "#5a6a4a";
      ctx.beginPath(); ctx.moveTo(w*0.15, g); ctx.quadraticCurveTo(w*0.5, g-70, w*0.85, g); ctx.fill();
      // Stairs up the hill
      ctx.fillStyle = "#7a7a6a";
      for (let i=0;i<10;i++) ctx.fillRect(w*0.44+i*1, g-5-i*5, w*0.12-i*1, 3);
      // Motherland Calls statue (detailed)
      ctx.fillStyle = "#c0c0b0";
      // Base
      ctx.fillRect(w*0.47, g-50, 10, 10);
      // Body
      ctx.beginPath(); ctx.moveTo(w*0.44, g-40); ctx.lineTo(w*0.5, g-145); ctx.lineTo(w*0.56, g-40); ctx.fill();
      // Head
      ctx.beginPath(); ctx.arc(w*0.5, g-148, 5, 0, Math.PI*2); ctx.fill();
      // Raised sword arm
      ctx.save(); ctx.translate(w*0.52, g-142); ctx.rotate(-0.4);
      ctx.fillRect(-1.5, -55, 3, 55); ctx.restore();
      // Left arm extended
      ctx.save(); ctx.translate(w*0.48, g-130); ctx.rotate(0.6);
      ctx.fillRect(-1, 0, 2, 25); ctx.restore();
      // Eternal flame
      ctx.fillStyle = "#c44"; ctx.beginPath(); ctx.arc(w*0.5, g-15, 8, 0, Math.PI*2); ctx.fill();
      ctx.fillStyle = "#fa0";
      ctx.beginPath(); ctx.moveTo(w*0.5-5, g-15); ctx.lineTo(w*0.5, g-30); ctx.lineTo(w*0.5+5, g-15); ctx.fill();
      ctx.fillStyle = "#ff6";
      ctx.beginPath(); ctx.moveTo(w*0.5-3, g-15); ctx.lineTo(w*0.5, g-25); ctx.lineTo(w*0.5+3, g-15); ctx.fill();
      // Ruined mill (preserved WWII ruin)
      ctx.fillStyle = "#8a7a6a"; ctx.fillRect(w*0.15, g-55, 25, 43);
      ctx.fillStyle = "#7a6a5a";
      ctx.fillRect(w*0.15, g-55, 25, 3);
      // Holes in wall
      ctx.fillStyle = "#4a3a2a";
      ctx.fillRect(w*0.16, g-45, 6, 8); ctx.fillRect(w*0.17, g-30, 8, 6);
      // Panorama Museum
      ctx.fillStyle = "#c0b8a0";
      ctx.beginPath(); ctx.arc(w*0.78, g-35, 22, Math.PI, 0); ctx.fill();
      ctx.fillRect(w*0.78-22, g-35, 44, 23);
      for (let i=0;i<4;i++) drawWindow(ctx, w*0.76-8+i*10, g-28, 5, 8, false);
      // Trees
      for (let i=0;i<4;i++) drawTree(ctx, w*0.62+i*14, g, 20, 'round');
    },
    trivia: [
      "The Battle of Stalingrad was the bloodiest battle in human history.",
      "The Motherland Calls statue stands 85 meters tall, one of the tallest in the world.",
      "The city was renamed from Stalingrad to Volgograd in 1961 after de-Stalinization.",
      "Over 2 million casualties occurred during the Battle of Stalingrad.",
      "Mamayev Kurgan hill changed hands multiple times during the battle."
    ],
    famousPeople: [
      { name: "Василий Зайцев", nameEn: "Vasily Zaitsev", fame: "Legendary WWII sniper who fought at the Battle of Stalingrad, credited with 225 kills.", wiki: "https://en.wikipedia.org/wiki/Vasily_Zaitsev" },
      { name: "Яков Павлов", nameEn: "Yakov Pavlov", fame: "Sergeant who defended 'Pavlov's House' for 60 days during the Battle of Stalingrad.", wiki: "https://en.wikipedia.org/wiki/Yakov_Pavlov" }
    ]
  },
  {
    name: "Одесса", nameEn: "Odessa",
    image: "", wiki: "https://en.wikipedia.org/wiki/Odesa",
    colors: { sky: "#2a3a4a", ground: "#8a8a6a", accent: "#4a90b0" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      drawBirds(ctx, w*0.6, h*0.08, 5);
      // Black Sea
      ctx.fillStyle = "#2a4a6a"; ctx.fillRect(0, g-8, w, 28);
      ctx.fillStyle = "rgba(60,120,160,0.1)";
      for (let i=0;i<15;i++) ctx.fillRect(i*w/15, g-3+Math.sin(i*0.7)*2, w/15-2, 2);
      // Ship in harbor
      ctx.fillStyle = "#555"; ctx.fillRect(w*0.08, g-12, 30, 6);
      ctx.fillStyle = "#c44"; ctx.fillRect(w*0.12, g-18, 4, 8);
      ctx.fillStyle = "#fff"; ctx.fillRect(w*0.1, g-10, 8, 3);
      // Potemkin Stairs (detailed)
      ctx.fillStyle = "#c0b8a0";
      for (let i=0;i<12;i++) ctx.fillRect(w*0.32+i*2, g-8-i*8, w*0.18-i*1.5, 8);
      // Railings
      ctx.strokeStyle = "#a0a090"; ctx.lineWidth = 0.5;
      ctx.beginPath(); ctx.moveTo(w*0.32, g-8); ctx.lineTo(w*0.56, g-104); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(w*0.5, g-8); ctx.lineTo(w*0.56, g-50); ctx.stroke();
      // Duc de Richelieu statue
      ctx.fillStyle = "#808080"; ctx.fillRect(w*0.44, g-100, 4, 12);
      ctx.fillRect(w*0.42, g-88, 8, 3);
      ctx.beginPath(); ctx.arc(w*0.46, g-105, 5, 0, Math.PI*2); ctx.fill();
      // Opera House (detailed)
      ctx.fillStyle = "#e0d8c0"; ctx.fillRect(w*0.58, g-75, w*0.32, 63);
      ctx.fillStyle = "#c8c0a0"; drawDome(ctx, w*0.74, g-80, 22, 16);
      for (let i=0;i<6;i++) ctx.fillRect(w*0.6+i*w*0.045, g-70, 5, 48);
      for (let i=0;i<5;i++) drawWindow(ctx, w*0.61+i*w*0.045+6, g-62, 6, 10, i%2===0);
      ctx.fillStyle = "#d0c8b0"; ctx.fillRect(w*0.58, g-78, w*0.32, 5);
      // Entrance arch
      ctx.fillStyle = "#b0a890";
      ctx.beginPath(); ctx.arc(w*0.74, g-20, 12, Math.PI, 0); ctx.fill();
      // Vorontsov Lighthouse
      ctx.fillStyle = "#c0c0c0"; ctx.fillRect(w*0.02, g-60, 6, 48);
      ctx.fillStyle = "#c44"; ctx.fillRect(w*0.02, g-63, 6, 5);
      ctx.fillStyle = "#ff8"; ctx.beginPath(); ctx.arc(w*0.05, g-60, 3, 0, Math.PI*2); ctx.fill();
      // Trees
      for (let i=0;i<4;i++) drawTree(ctx, w*0.55+i*10, g, 18, 'round');
    },
    trivia: [
      "Odessa's Potemkin Stairs have 192 steps and were featured in Eisenstein's famous film.",
      "The city was founded by Catherine the Great in 1794.",
      "Odessa was known as the 'Pearl of the Black Sea' during the Russian Empire.",
      "The Odessa Catacombs stretch over 2,500 km, the longest in the world.",
      "Odessa was a major hub for Soviet cinema and humor."
    ],
    famousPeople: [
      { name: "Исаак Бабель", nameEn: "Isaac Babel", fame: "Author of 'Odessa Tales' and 'Red Cavalry', master of the short story.", wiki: "https://en.wikipedia.org/wiki/Isaac_Babel" },
      { name: "Леонид Утёсов", nameEn: "Leonid Utesov", fame: "Jazz musician and singer, one of the most popular Soviet entertainers.", wiki: "https://en.wikipedia.org/wiki/Leonid_Utesov" },
      { name: "Анна Ахматова", nameEn: "Anna Akhmatova", fame: "One of the greatest Russian poets of the 20th century, born near Odessa.", wiki: "https://en.wikipedia.org/wiki/Anna_Akhmatova" }
    ]
  },
  {
    name: "Рига", nameEn: "Riga",
    image: "", wiki: "https://en.wikipedia.org/wiki/Riga",
    colors: { sky: "#2a3a3a", ground: "#5a5a4a", accent: "#8a4a2a" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      // Daugava river
      ctx.fillStyle = "#3a5a6a"; ctx.fillRect(0, g-8, w, 18);
      // Art Nouveau buildings (detailed)
      const bColors = ["#c08050","#d0b080","#a08060","#b09070","#c0a070","#d0a060"];
      for (let i=0;i<6;i++) {
        const bh = 55+i*8; ctx.fillStyle = bColors[i];
        ctx.fillRect(w*0.05+i*w*0.12, g-bh, w*0.1, bh);
        // Gabled roofs
        ctx.fillStyle = "#6a3020";
        ctx.beginPath(); ctx.moveTo(w*0.05+i*w*0.12, g-bh); ctx.lineTo(w*0.05+i*w*0.12+w*0.05, g-bh-18); ctx.lineTo(w*0.05+i*w*0.12+w*0.1, g-bh); ctx.fill();
        // Windows
        for (let j=0;j<2;j++) for (let k=0;k<3;k++) drawWindow(ctx, w*0.06+i*w*0.12+j*14, g-bh+10+k*14, 6, 8, (i+j+k)%3===0);
        // Art Nouveau decorations
        ctx.fillStyle = "#e0d0b0";
        ctx.beginPath(); ctx.arc(w*0.05+i*w*0.12+w*0.05, g-bh+5, 4, 0, Math.PI*2); ctx.fill();
      }
      // St Peter's Church (detailed spire)
      ctx.fillStyle = "#4a4a4a"; ctx.fillRect(w*0.42, g-80, 18, 68);
      ctx.fillRect(w*0.44, g-140, 5, 65);
      ctx.beginPath(); ctx.moveTo(w*0.44, g-140); ctx.lineTo(w*0.465, g-165); ctx.lineTo(w*0.49, g-140); ctx.fill();
      // Tiered spire
      ctx.fillRect(w*0.43, g-120, 12, 5); ctx.fillRect(w*0.44, g-130, 10, 5);
      // Clock
      ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(w*0.45+4, g-90, 5, 0, Math.PI*2); ctx.fill();
      // Freedom Monument
      ctx.fillStyle = "#c0c0c0"; ctx.fillRect(w*0.82-2, g-110, 4, 110);
      ctx.fillStyle = "#c8a830";
      ctx.beginPath(); ctx.arc(w*0.82, g-115, 6, 0, Math.PI*2); ctx.fill();
      // Three stars
      ctx.fillRect(w*0.82-1, g-125, 2, 12);
      drawStar(ctx, w*0.82, g-128, 4);
      // House of Blackheads
      ctx.fillStyle = "#3a3a3a"; ctx.fillRect(w*0.72, g-65, w*0.08, 53);
      ctx.fillStyle = "#c44"; ctx.fillRect(w*0.72, g-68, w*0.08, 5);
      for (let i=0;i<2;i++) drawWindow(ctx, w*0.73+i*10, g-55, 5, 8, true);
      // Trees
      for (let i=0;i<3;i++) drawTree(ctx, w*0.38+i*10, g, 18, 'round');
    },
    trivia: [
      "Riga's Art Nouveau district has the highest concentration of such buildings in the world.",
      "The city was founded in 1201 by German crusaders.",
      "Riga's Central Market is housed in former Zeppelin hangars.",
      "The Freedom Monument was built in 1935 and survived the Soviet era.",
      "Riga was one of the largest cities in the Soviet Union."
    ],
    famousPeople: [
      { name: "Михаил Эйзенштейн", nameEn: "Mikhail Eisenstein", fame: "Architect who designed many of Riga's famous Art Nouveau buildings.", wiki: "https://en.wikipedia.org/wiki/Mikhail_Eisenstein" },
      { name: "Сергей Эйзенштейн", nameEn: "Sergei Eisenstein", fame: "Pioneering film director of 'Battleship Potemkin' and 'Ivan the Terrible', born in Riga.", wiki: "https://en.wikipedia.org/wiki/Sergei_Eisenstein" },
      { name: "Михаил Таль", nameEn: "Mikhail Tal", fame: "World Chess Champion (1960-61), known as 'The Magician from Riga'.", wiki: "https://en.wikipedia.org/wiki/Mikhail_Tal" }
    ]
  },
  {
    name: "Таллин", nameEn: "Tallinn",
    image: "", wiki: "https://en.wikipedia.org/wiki/Tallinn",
    colors: { sky: "#2a3a4a", ground: "#5a6a5a", accent: "#6a8a6a" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      drawBirds(ctx, w*0.3, h*0.12, 3);
      ctx.fillStyle = "#2a4a5a"; ctx.fillRect(w*0.7, g-8, w*0.3, 18);
      // Toompea hill
      ctx.fillStyle = "#5a6a4a";
      ctx.beginPath(); ctx.moveTo(w*0.05,g); ctx.quadraticCurveTo(w*0.25,g-50,w*0.5,g); ctx.fill();
      // Toompea Castle
      ctx.fillStyle = "#d0b0a0"; ctx.fillRect(w*0.12, g-85, w*0.28, 55);
      ctx.fillStyle = "#c44"; ctx.fillRect(w*0.12, g-85, w*0.28, 5);
      for (let i=0;i<5;i++) drawWindow(ctx, w*0.14+i*w*0.05, g-75, 6, 10, i%2===0);
      // Tall Hermann tower
      ctx.fillStyle = "#c0a890"; ctx.fillRect(w*0.15, g-115, 16, 35);
      ctx.fillStyle = "#6a3020";
      ctx.beginPath(); ctx.moveTo(w*0.15, g-115); ctx.lineTo(w*0.158, g-130); ctx.lineTo(w*0.166, g-115); ctx.fill();
      // Flag
      ctx.fillStyle = "#0066cc"; ctx.fillRect(w*0.168, g-128, 10, 3);
      ctx.fillStyle = "#000"; ctx.fillRect(w*0.168, g-125, 10, 3);
      ctx.fillStyle = "#fff"; ctx.fillRect(w*0.168, g-122, 10, 3);
      // St Olaf's Church
      ctx.fillStyle = "#5a5a5a"; ctx.fillRect(w*0.55, g-80, 14, 68);
      ctx.fillRect(w*0.555, g-150, 5, 75);
      ctx.beginPath(); ctx.moveTo(w*0.555, g-150); ctx.lineTo(w*0.58, g-170); ctx.lineTo(w*0.605, g-150); ctx.fill();
      // Alexander Nevsky Cathedral
      ctx.fillStyle = "#3a3a3a"; ctx.fillRect(w*0.3, g-70, 25, 40);
      ctx.fillStyle = "#444"; drawOnionDome(ctx, w*0.3+12, g-80, 10, 14);
      drawOnionDome(ctx, w*0.3+4, g-72, 6, 9);
      drawOnionDome(ctx, w*0.3+20, g-72, 6, 9);
      // Medieval town walls with towers
      ctx.fillStyle = "#a09080";
      for (let i=0;i<4;i++) {
        ctx.fillRect(w*0.45+i*w*0.08, g-65, 10, 53);
        ctx.fillStyle = "#8a3020";
        ctx.beginPath(); ctx.moveTo(w*0.45+i*w*0.08, g-65); ctx.lineTo(w*0.45+i*w*0.08+5, g-75); ctx.lineTo(w*0.45+i*w*0.08+10, g-65); ctx.fill();
        ctx.fillStyle = "#a09080";
      }
      // Wall between towers
      ctx.fillRect(w*0.46, g-50, w*0.3, 5);
      // Trees
      for (let i=0;i<3;i++) drawTree(ctx, w*0.82+i*12, g, 20, 'pine');
    },
    trivia: [
      "Tallinn's Old Town is one of the best-preserved medieval cities in Europe.",
      "The city was known as Reval during the German and Swedish periods.",
      "Tallinn's town wall still has 26 surviving towers.",
      "St Olaf's Church was the tallest building in the world in the 16th century.",
      "Estonia was the first Soviet republic to declare sovereignty in 1988."
    ],
    famousPeople: [
      { name: "Арво Пярт", nameEn: "Arvo Pärt", fame: "Composer, creator of 'tintinnabuli' style, one of the most performed living composers.", wiki: "https://en.wikipedia.org/wiki/Arvo_P%C3%A4rt" },
      { name: "Пауль Керес", nameEn: "Paul Keres", fame: "Chess grandmaster, one of the strongest players never to become World Champion.", wiki: "https://en.wikipedia.org/wiki/Paul_Keres" },
      { name: "Георг Отс", nameEn: "Georg Ots", fame: "Opera singer, one of the most beloved performers in the Soviet Union.", wiki: "https://en.wikipedia.org/wiki/Georg_Ots" }
    ]
  },
  {
    name: "Вильнюс", nameEn: "Vilnius",
    image: "", wiki: "https://en.wikipedia.org/wiki/Vilnius",
    colors: { sky: "#2a2a3a", ground: "#5a5a3a", accent: "#c08040" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      // Gediminas Hill
      ctx.fillStyle = "#4a6a3a";
      ctx.beginPath(); ctx.moveTo(w*0.02,g); ctx.quadraticCurveTo(w*0.22,g-60,w*0.42,g); ctx.fill();
      // Gediminas Tower
      ctx.fillStyle = "#a06040"; ctx.fillRect(w*0.18, g-95, 28, 55);
      ctx.fillStyle = "#8a5030"; ctx.fillRect(w*0.18, g-100, 28, 8);
      for (let i=0;i<3;i++) ctx.fillRect(w*0.185+i*3, g-102, 2, 4);
      for (let i=0;i<2;i++) drawWindow(ctx, w*0.19+i*10, g-85, 6, 10, false);
      // Lithuanian flag
      ctx.fillStyle = "#c8a830"; ctx.fillRect(w*0.21, g-110, 8, 3);
      ctx.fillStyle = "#2a7a2a"; ctx.fillRect(w*0.21, g-107, 8, 3);
      ctx.fillStyle = "#c44"; ctx.fillRect(w*0.21, g-104, 8, 3);
      // Cathedral Square
      ctx.fillStyle = "#e0d8c0"; ctx.fillRect(w*0.48, g-65, w*0.28, 53);
      for (let i=0;i<6;i++) ctx.fillRect(w*0.5+i*w*0.04, g-60, 5, 40);
      for (let i=0;i<5;i++) drawWindow(ctx, w*0.51+i*w*0.04+6, g-55, 5, 8, i%2===0);
      ctx.fillStyle = "#d0c8b0"; ctx.fillRect(w*0.48, g-68, w*0.28, 5);
      // Pediment
      ctx.beginPath(); ctx.moveTo(w*0.48, g-68); ctx.lineTo(w*0.62, g-80); ctx.lineTo(w*0.76, g-68); ctx.fill();
      // Bell tower
      ctx.fillStyle = "#c0b8a0"; ctx.fillRect(w*0.78, g-100, 16, 88);
      ctx.fillStyle = "#c8a830";
      ctx.beginPath(); ctx.moveTo(w*0.78, g-100); ctx.lineTo(w*0.786+8, g-118); ctx.lineTo(w*0.78+16, g-100); ctx.fill();
      // Cross on top
      ctx.fillRect(w*0.793, g-125, 2, 10); ctx.fillRect(w*0.789, g-122, 10, 2);
      // Gate of Dawn
      ctx.fillStyle = "#b09070"; ctx.fillRect(w*0.88, g-50, w*0.08, 38);
      ctx.beginPath(); ctx.arc(w*0.92, g-50, w*0.04, Math.PI, 0); ctx.fill();
      ctx.fillStyle = "#c8a830"; ctx.beginPath(); ctx.arc(w*0.92, g-42, 4, 0, Math.PI*2); ctx.fill();
      // Trees
      for (let i=0;i<5;i++) drawTree(ctx, w*0.42+i*12, g, 22, 'round');
    },
    trivia: [
      "Vilnius Old Town is one of the largest surviving medieval old towns in Europe.",
      "Gediminas Tower is the symbol of Vilnius, dating back to the 14th century.",
      "The Gate of Dawn is one of the most important religious sites in Lithuania.",
      "Vilnius University, founded in 1579, is one of the oldest in Eastern Europe.",
      "Lithuania was the first Soviet republic to declare independence in 1990."
    ],
    famousPeople: [
      { name: "Чеслав Милош", nameEn: "Czesław Miłosz", fame: "Nobel Prize-winning poet and novelist, born near Vilnius.", wiki: "https://en.wikipedia.org/wiki/Czes%C5%82aw_Mi%C5%82osz" },
      { name: "Феликс Дзержинский", nameEn: "Felix Dzerzhinsky", fame: "Founder of the Cheka (Soviet secret police), born near Vilnius.", wiki: "https://en.wikipedia.org/wiki/Felix_Dzerzhinsky" },
      { name: "Жак Липшиц", nameEn: "Jacques Lipchitz", fame: "Cubist sculptor, born in Druskininkai near Vilnius.", wiki: "https://en.wikipedia.org/wiki/Jacques_Lipchitz" }
    ]
  },
  {
    name: "Фрунзе", nameEn: "Frunze",
    image: "", wiki: "https://en.wikipedia.org/wiki/Bishkek",
    colors: { sky: "#2a3a4a", ground: "#6a7a4a", accent: "#5a9a6a" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      // Tian Shan mountains (detailed)
      ctx.fillStyle = "#6a7a8a";
      ctx.beginPath(); ctx.moveTo(0, g-15); ctx.lineTo(w*0.12, g-80); ctx.lineTo(w*0.25, g-45); ctx.lineTo(w*0.4, g-100);
      ctx.lineTo(w*0.55, g-55); ctx.lineTo(w*0.65, g-130); ctx.lineTo(w*0.78, g-65); ctx.lineTo(w*0.9, g-90);
      ctx.lineTo(w, g-30); ctx.lineTo(w, g); ctx.lineTo(0, g); ctx.fill();
      ctx.fillStyle = "#fff";
      ctx.beginPath(); ctx.moveTo(w*0.65, g-130); ctx.lineTo(w*0.6, g-100); ctx.lineTo(w*0.7, g-100); ctx.fill();
      ctx.beginPath(); ctx.moveTo(w*0.9, g-90); ctx.lineTo(w*0.87, g-72); ctx.lineTo(w*0.93, g-72); ctx.fill();
      // Ala-Too Square
      ctx.fillStyle = "#8a8a7a"; ctx.fillRect(w*0.2, g-8, w*0.5, 6);
      // Manas statue
      ctx.fillStyle = "#c0c0c0"; ctx.fillRect(w*0.43, g-90, 5, 78);
      ctx.fillStyle = "#c44"; ctx.fillRect(w*0.41, g-95, 9, 8);
      ctx.fillStyle = "#aaa"; ctx.fillRect(w*0.4, g-15, 12, 5);
      // Soviet-era buildings
      ctx.fillStyle = "#8a8a7a"; ctx.fillRect(w*0.05, g-55, w*0.15, 43);
      ctx.fillStyle = "#7a7a6a";
      for (let i=0;i<3;i++) for (let j=0;j<2;j++) drawWindow(ctx, w*0.06+i*w*0.04, g-50+j*14, 6, 8, (i+j)%2===0);
      // White House (parliament)
      ctx.fillStyle = "#e0e0d8"; ctx.fillRect(w*0.55, g-60, w*0.2, 48);
      ctx.fillStyle = "#d0d0c8";
      for (let i=0;i<4;i++) ctx.fillRect(w*0.56+i*w*0.045, g-55, 5, 35);
      ctx.fillStyle = "#c0c0b8"; ctx.fillRect(w*0.55, g-63, w*0.2, 5);
      // Flagpole
      ctx.fillStyle = "#c44"; ctx.fillRect(w*0.65-1, g-80, 2, 22);
      ctx.fillStyle = "#c44"; ctx.fillRect(w*0.65, g-80, 8, 5);
      // Trees (lots of green)
      for (let i=0;i<8;i++) drawTree(ctx, w*0.08+i*w*0.05, g, 20+i%3*4, i%2===0?'pine':'round');
      for (let i=0;i<4;i++) drawTree(ctx, w*0.78+i*12, g, 22, 'round');
    },
    trivia: [
      "Frunze was known as Bishkek before and after the Soviet era, named after Bolshevik general Mikhail Frunze.",
      "The city sits at 800 meters elevation at the foot of the Tian Shan mountains.",
      "Frunze's Osh Bazaar is one of the largest open-air markets in Central Asia.",
      "The city has more green space per capita than most Central Asian capitals.",
      "Kyrgyzstan's national drink, kumis (fermented mare's milk), is sold on Frunze streets."
    ],
    famousPeople: [
      { name: "Михаил Фрунзе", nameEn: "Mikhail Frunze", fame: "Bolshevik military leader, the city was named after him during the Soviet era.", wiki: "https://en.wikipedia.org/wiki/Mikhail_Frunze" },
      { name: "Чингиз Айтматов", nameEn: "Chingiz Aitmatov", fame: "Novelist and diplomat, author of 'The Day Lasts More Than a Hundred Years'.", wiki: "https://en.wikipedia.org/wiki/Chingiz_Aitmatov" }
    ]
  },
  {
    name: "Душанбе", nameEn: "Dushanbe",
    image: "", wiki: "https://en.wikipedia.org/wiki/Dushanbe",
    colors: { sky: "#3a2a2a", ground: "#7a6a4a", accent: "#c09050" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      // Pamir mountains
      ctx.fillStyle = "#7a6a5a";
      ctx.beginPath(); ctx.moveTo(0, g-10); ctx.lineTo(w*0.18, g-90); ctx.lineTo(w*0.35, g-45); ctx.lineTo(w*0.5, g-110);
      ctx.lineTo(w*0.65, g-50); ctx.lineTo(w*0.78, g-140); ctx.lineTo(w*0.9, g-60); ctx.lineTo(w, g-20); ctx.lineTo(w, g); ctx.lineTo(0, g); ctx.fill();
      ctx.fillStyle = "#fff";
      ctx.beginPath(); ctx.moveTo(w*0.78, g-140); ctx.lineTo(w*0.73, g-108); ctx.lineTo(w*0.83, g-108); ctx.fill();
      ctx.beginPath(); ctx.moveTo(w*0.5, g-110); ctx.lineTo(w*0.47, g-90); ctx.lineTo(w*0.53, g-90); ctx.fill();
      // Ismoili Somoni monument
      ctx.fillStyle = "#c8a830"; ctx.fillRect(w*0.44, g-105, 7, 75);
      ctx.beginPath(); ctx.arc(w*0.475, g-110, 9, 0, Math.PI*2); ctx.fill();
      ctx.fillStyle = "#b09020"; ctx.fillRect(w*0.44-8, g-35, 23, 5);
      // National Museum
      ctx.fillStyle = "#d0c0a0"; ctx.fillRect(w*0.08, g-55, w*0.28, 43);
      ctx.fillStyle = "#b0a080"; drawDome(ctx, w*0.22, g-60, 20, 16);
      for (let i=0;i<5;i++) ctx.fillRect(w*0.1+i*w*0.05, g-50, 5, 30);
      for (let i=0;i<4;i++) drawWindow(ctx, w*0.11+i*w*0.05+6, g-45, 5, 8, i%2===0);
      // Rudaki Park
      for (let i=0;i<6;i++) drawTree(ctx, w*0.38+i*14, g, 22, 'round');
      // Flagpole (one of tallest in world)
      ctx.fillStyle = "#c0c0c0"; ctx.fillRect(w*0.62, g-120, 2, 108);
      ctx.fillStyle = "#c44"; ctx.fillRect(w*0.622, g-120, 10, 6);
      ctx.fillStyle = "#fff"; ctx.fillRect(w*0.622, g-114, 10, 6);
      ctx.fillStyle = "#2a8a2a"; ctx.fillRect(w*0.622, g-108, 10, 6);
    },
    trivia: [
      "Dushanbe means 'Monday' in Tajik, as it grew from a Monday market village.",
      "The Pamir Highway near Dushanbe is one of the highest roads in the world.",
      "The Ismoili Somoni monument stands in the center of the city.",
      "Dushanbe's population grew from 6,000 in 1920 to over 500,000 by 1989.",
      "Tajikistan has the youngest population of any former Soviet republic."
    ],
    famousPeople: [
      { name: "Мирзо Турсунзаде", nameEn: "Mirzo Tursunzoda", fame: "National poet of Tajikistan, Lenin Prize laureate.", wiki: "https://en.wikipedia.org/wiki/Mirzo_Tursunzoda" },
      { name: "Садриддин Айни", nameEn: "Sadriddin Ayni", fame: "Father of modern Tajik literature, first president of the Tajik Academy of Sciences.", wiki: "https://en.wikipedia.org/wiki/Sadriddin_Ayni" }
    ]
  },
  {
    name: "Ашхабад", nameEn: "Ashgabat",
    image: "", wiki: "https://en.wikipedia.org/wiki/Ashgabat",
    colors: { sky: "#3a3a2a", ground: "#b0a070", accent: "#fff" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      // Desert dunes
      ctx.fillStyle = "#c0a060";
      ctx.beginPath(); ctx.moveTo(0, g); ctx.quadraticCurveTo(w*0.2, g-25, w*0.4, g-8);
      ctx.quadraticCurveTo(w*0.6, g-20, w*0.8, g-5); ctx.quadraticCurveTo(w*0.9, g-12, w, g);
      ctx.lineTo(w, g+10); ctx.lineTo(0, g+10); ctx.fill();
      // White marble buildings (Ashgabat is famous for these)
      ctx.fillStyle = "#f0f0e8";
      ctx.fillRect(w*0.1, g-85, w*0.12, 73); ctx.fillRect(w*0.25, g-100, w*0.14, 88);
      ctx.fillRect(w*0.42, g-75, w*0.12, 63); ctx.fillRect(w*0.57, g-90, w*0.1, 78);
      // Windows on buildings
      for (let b=0;b<4;b++) {
        const bx=[w*0.1,w*0.25,w*0.42,w*0.57][b], bw=[w*0.12,w*0.14,w*0.12,w*0.1][b], bh=[85,100,75,90][b];
        for (let i=0;i<3;i++) for (let j=0;j<4;j++) {
          ctx.fillStyle = "#c0d0e0"; ctx.fillRect(bx+5+i*(bw/3-2), g-bh+12+j*16, 6, 8);
        }
      }
      // Gold domes
      ctx.fillStyle = "#c8a830"; drawDome(ctx, w*0.32, g-105, 16, 12);
      drawDome(ctx, w*0.62, g-95, 12, 9);
      // Neutrality Arch (tripod with rotating statue)
      ctx.fillStyle = "#c8a830"; ctx.fillRect(w*0.78-2, g-130, 4, 118);
      // Tripod legs
      ctx.beginPath(); ctx.moveTo(w*0.78, g-130); ctx.lineTo(w*0.74, g-80); ctx.lineTo(w*0.76, g-80); ctx.fill();
      ctx.beginPath(); ctx.moveTo(w*0.78, g-130); ctx.lineTo(w*0.82, g-80); ctx.lineTo(w*0.8, g-80); ctx.fill();
      ctx.beginPath(); ctx.arc(w*0.78, g-135, 10, 0, Math.PI*2); ctx.fill();
      // Gold statue on top
      ctx.fillStyle = "#e8c830"; ctx.fillRect(w*0.78-2, g-148, 4, 15);
      ctx.beginPath(); ctx.arc(w*0.78, g-150, 3, 0, Math.PI*2); ctx.fill();
      // Kopet Dag mountains in distance
      ctx.fillStyle = "rgba(120,100,80,0.3)";
      ctx.beginPath(); ctx.moveTo(0,g-5); ctx.lineTo(w*0.15,g-30); ctx.lineTo(w*0.3,g-15); ctx.lineTo(w*0.5,g-35);
      ctx.lineTo(w*0.7,g-20); ctx.lineTo(w,g-10); ctx.lineTo(w,g); ctx.lineTo(0,g); ctx.fill();
      // Trees
      for (let i=0;i<3;i++) drawTree(ctx, w*0.7+i*14, g, 18, 'round');
    },
    trivia: [
      "Ashgabat holds the Guinness record for the most white marble buildings.",
      "The city was almost completely destroyed by an earthquake in 1948.",
      "The Neutrality Arch features a gold statue that rotates to face the sun.",
      "Ashgabat's Turkmenbashi Ruhy Mosque can hold 10,000 worshippers.",
      "The Karakum Desert surrounds the city on three sides."
    ],
    famousPeople: [
      { name: "Махтумкули Фраги", nameEn: "Magtymguly Pyragy", fame: "National poet of Turkmenistan, considered the father of Turkmen literature.", wiki: "https://en.wikipedia.org/wiki/Magtymguly_Pyragy" },
      { name: "Сапармурат Ниязов", nameEn: "Saparmurat Niyazov", fame: "First President of Turkmenistan, known as 'Turkmenbashi' (Father of the Turkmens).", wiki: "https://en.wikipedia.org/wiki/Saparmurat_Niyazov" }
    ]
  },
  {
    name: "Казань", nameEn: "Kazan",
    image: "", wiki: "https://en.wikipedia.org/wiki/Kazan",
    colors: { sky: "#2a2a3a", ground: "#5a5a4a", accent: "#4a9a7a" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      ctx.fillStyle = "rgba(150,170,160,0.1)"; drawCloud(ctx, w*0.5, h*0.1, 24);
      // Kremlin walls
      ctx.fillStyle = "#e0d0b0"; ctx.fillRect(w*0.1, g-50, w*0.75, 38);
      ctx.fillStyle = "#d0c0a0";
      for (let i=0;i<18;i++) ctx.fillRect(w*0.1+i*w*0.042, g-55, w*0.028, 8);
      // Qol Sharif Mosque
      ctx.fillStyle = "#4a9aaa"; drawOnionDome(ctx, w*0.38, g-110, 20, 28);
      ctx.fillStyle = "#e0d8c0"; ctx.fillRect(w*0.3, g-75, w*0.17, 63);
      for (let i=0;i<3;i++) drawWindow(ctx, w*0.32+i*w*0.05, g-65, 6, 10, true);
      // Minarets
      ctx.fillStyle = "#4a9aaa"; ctx.fillRect(w*0.28, g-120, 4, 58); ctx.fillRect(w*0.49, g-120, 4, 58);
      drawDome(ctx, w*0.3, g-122, 4, 5); drawDome(ctx, w*0.51, g-122, 4, 5);
      // Suyumbike Tower (leaning)
      ctx.save(); ctx.translate(w*0.65, g); ctx.rotate(-0.05);
      ctx.fillStyle = "#c08060";
      ctx.fillRect(-8, -105, 16, 25); ctx.fillRect(-6, -80, 12, 20); ctx.fillRect(-5, -60, 10, 48);
      for (let i=0;i<2;i++) drawWindow(ctx, -4+i*5, -95, 4, 6, false);
      ctx.fillStyle = "#c44"; drawStar(ctx, 0, -110, 6);
      ctx.restore();
      // Annunciation Cathedral
      ctx.fillStyle = "#fff"; drawOnionDome(ctx, w*0.55, g-85, 10, 14);
      ctx.fillStyle = "#e8d8c0"; ctx.fillRect(w*0.52, g-65, 16, 53);
      // Kazanka River
      ctx.fillStyle = "#3a6a8a"; ctx.fillRect(0, g-8, w, 16);
      // Trees
      for (let i=0;i<4;i++) drawTree(ctx, w*0.82+i*12, g, 20, 'round');
    },
    trivia: [
      "Kazan is over 1,000 years old, making it one of Russia's oldest cities.",
      "The Qol Sharif Mosque in the Kremlin is one of Europe's largest mosques.",
      "Kazan is where Tatar and Russian cultures uniquely blend together.",
      "The Suyumbike Tower leans 1.98 meters, similar to the Tower of Pisa.",
      "Kazan hosted the 2013 Summer Universiade and 2018 FIFA World Cup matches."
    ],
    famousPeople: [
      { name: "Лев Толстой", nameEn: "Leo Tolstoy", fame: "Author of 'War and Peace' and 'Anna Karenina', studied at Kazan University.", wiki: "https://en.wikipedia.org/wiki/Leo_Tolstoy" },
      { name: "Николай Лобачевский", nameEn: "Nikolai Lobachevsky", fame: "Mathematician who pioneered non-Euclidean geometry, rector of Kazan University.", wiki: "https://en.wikipedia.org/wiki/Nikolai_Lobachevsky" },
      { name: "Муса Джалиль", nameEn: "Musa Jalil", fame: "Tatar poet and resistance hero, executed by the Nazis, posthumous Hero of the Soviet Union.", wiki: "https://en.wikipedia.org/wiki/Musa_Jalil" }
    ]
  },
  {
    name: "Свердловск", nameEn: "Sverdlovsk",
    image: "", wiki: "https://en.wikipedia.org/wiki/Yekaterinburg",
    colors: { sky: "#1a2a3a", ground: "#4a4a4a", accent: "#7a8a9a" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      // Ural mountains
      ctx.fillStyle = "#5a6a5a";
      ctx.beginPath(); ctx.moveTo(0, g-8); ctx.lineTo(w*0.15, g-55); ctx.lineTo(w*0.3, g-30); ctx.lineTo(w*0.45, g-65);
      ctx.lineTo(w*0.6, g-35); ctx.lineTo(w*0.75, g-70); ctx.lineTo(w*0.9, g-40); ctx.lineTo(w, g-20); ctx.lineTo(w, g); ctx.lineTo(0, g); ctx.fill();
      // Iset River
      ctx.fillStyle = "#3a5a6a"; ctx.fillRect(0, g-8, w, 16);
      // Church on the Blood
      ctx.fillStyle = "#e0d0b0"; ctx.fillRect(w*0.3, g-85, w*0.22, 63);
      ctx.fillStyle = "#c8a830"; drawOnionDome(ctx, w*0.41, g-100, 16, 22);
      drawOnionDome(ctx, w*0.34, g-90, 10, 14); drawOnionDome(ctx, w*0.48, g-90, 10, 14);
      for (let i=0;i<4;i++) drawWindow(ctx, w*0.32+i*w*0.05, g-75, 6, 10, i%2===0);
      // Vysotsky skyscraper
      ctx.fillStyle = "#6a7a8a"; ctx.fillRect(w*0.7, g-110, 18, 98);
      ctx.fillStyle = "#5a6a7a";
      for (let i=0;i<8;i++) for (let j=0;j<2;j++) drawWindow(ctx, w*0.71+j*7, g-105+i*12, 4, 6, i%3===0);
      ctx.fillStyle = "#4a5a6a"; ctx.fillRect(w*0.7, g-115, 18, 8);
      // Industrial buildings
      ctx.fillStyle = "#5a5a5a"; ctx.fillRect(w*0.08, g-55, w*0.15, 43);
      ctx.fillStyle = "#444"; ctx.fillRect(w*0.12, g-85, 6, 35);
      // Smoke
      ctx.fillStyle = "rgba(150,150,150,0.2)";
      ctx.beginPath(); ctx.arc(w*0.15, g-90, 8, 0, Math.PI*2); ctx.fill();
      ctx.beginPath(); ctx.arc(w*0.17, g-100, 10, 0, Math.PI*2); ctx.fill();
      // Europe-Asia border monument
      ctx.fillStyle = "#c0c0c0"; ctx.fillRect(w*0.58, g-65, 3, 53);
      ctx.fillStyle = "#aaa"; ctx.beginPath(); ctx.arc(w*0.595, g-68, 5, 0, Math.PI*2); ctx.fill();
      // Trees
      for (let i=0;i<5;i++) drawTree(ctx, w*0.85+i*10, g, 18, 'pine');
    },
    trivia: [
      "Sverdlovsk (now Yekaterinburg) sits on the border between Europe and Asia.",
      "The Romanov royal family was executed here in 1918.",
      "The Church on the Blood was built on the site of the Romanov execution.",
      "Boris Yeltsin, Russia's first president, began his career in Sverdlovsk.",
      "The city was a major Soviet industrial center, closed to foreigners until 1990."
    ],
    famousPeople: [
      { name: "Борис Ельцин", nameEn: "Boris Yeltsin", fame: "First President of the Russian Federation, began his political career in Sverdlovsk.", wiki: "https://en.wikipedia.org/wiki/Boris_Yeltsin" },
      { name: "Павел Бажов", nameEn: "Pavel Bazhov", fame: "Author of 'The Malachite Box', beloved collection of Ural folk tales.", wiki: "https://en.wikipedia.org/wiki/Pavel_Bazhov" },
      { name: "Эрнст Неизвестный", nameEn: "Ernst Neizvestny", fame: "Sculptor known for monumental works, born in Sverdlovsk.", wiki: "https://en.wikipedia.org/wiki/Ernst_Neizvestny" }
    ]
  },
  {
    name: "Мурманск", nameEn: "Murmansk",
    image: "", wiki: "https://en.wikipedia.org/wiki/Murmansk",
    colors: { sky: "#0a1a2a", ground: "#3a4a4a", accent: "#4a7a9a" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      // Arctic sea with ice
      ctx.fillStyle = "#1a3a5a"; ctx.fillRect(0, g-8, w, 20);
      ctx.fillStyle = "#c0d0e0";
      [[0.08,12],[0.25,16],[0.42,10],[0.6,14],[0.78,11]].forEach(([x,sz]) => ctx.fillRect(w*x, g-8, sz, 6));
      // Aurora borealis
      ctx.strokeStyle = "#4aaa6a"; ctx.lineWidth = 3; ctx.globalAlpha = 0.35;
      ctx.beginPath(); ctx.moveTo(0, g-100); ctx.quadraticCurveTo(w*0.25, g-150, w*0.5, g-110);
      ctx.quadraticCurveTo(w*0.75, g-145, w, g-100); ctx.stroke();
      ctx.strokeStyle = "#4a8aaa"; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(0, g-115); ctx.quadraticCurveTo(w*0.35, g-160, w*0.65, g-120);
      ctx.quadraticCurveTo(w*0.85, g-150, w, g-115); ctx.stroke();
      ctx.strokeStyle = "#8a4aaa"; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(w*0.1, g-105); ctx.quadraticCurveTo(w*0.4, g-140, w*0.7, g-108);
      ctx.quadraticCurveTo(w*0.9, g-135, w, g-108); ctx.stroke();
      ctx.globalAlpha = 1;
      // Kola Bay hill
      ctx.fillStyle = "#3a4a3a";
      ctx.beginPath(); ctx.moveTo(w*0.15, g); ctx.quadraticCurveTo(w*0.45, g-55, w*0.75, g); ctx.fill();
      // Alyosha monument
      ctx.fillStyle = "#808080"; ctx.fillRect(w*0.43, g-130, 12, 85);
      ctx.beginPath(); ctx.arc(w*0.49, g-135, 7, 0, Math.PI*2); ctx.fill();
      // Rifle
      ctx.save(); ctx.translate(w*0.46, g-120); ctx.rotate(0.3);
      ctx.fillRect(-1, 0, 2, 30); ctx.restore();
      // Base
      ctx.fillStyle = "#6a6a6a"; ctx.fillRect(w*0.4, g-45, 20, 5);
      // Nuclear icebreaker Lenin
      ctx.fillStyle = "#555"; ctx.fillRect(w*0.08, g-18, 35, 10);
      ctx.fillStyle = "#c44"; ctx.fillRect(w*0.12, g-24, w*0.08, 7);
      ctx.fillStyle = "#fff"; ctx.fillRect(w*0.1, g-15, 10, 4);
      // Smokestack
      ctx.fillStyle = "#444"; ctx.fillRect(w*0.18, g-30, 4, 14);
      // Soviet apartment blocks
      ctx.fillStyle = "#5a6a6a"; ctx.fillRect(w*0.7, g-55, w*0.12, 43);
      ctx.fillStyle = "#4a8aaa"; ctx.fillRect(w*0.7, g-55, w*0.12, 4);
      for (let i=0;i<3;i++) for (let j=0;j<3;j++) drawWindow(ctx, w*0.71+i*10, g-48+j*12, 5, 6, (i+j)%2===0);
      ctx.fillStyle = "#6a7a7a"; ctx.fillRect(w*0.85, g-48, w*0.1, 36);
      ctx.fillStyle = "#aa6a4a"; ctx.fillRect(w*0.85, g-48, w*0.1, 4);
      for (let i=0;i<2;i++) for (let j=0;j<2;j++) drawWindow(ctx, w*0.86+i*10, g-42+j*12, 5, 6, true);
    },
    trivia: [
      "Murmansk is the largest city above the Arctic Circle.",
      "The city experiences polar night for 40 days each winter.",
      "The nuclear icebreaker Lenin is permanently docked in Murmansk as a museum.",
      "Murmansk was a vital supply port during WWII via the Arctic convoys.",
      "The Alyosha monument stands 35 meters tall overlooking the Kola Bay."
    ],
    famousPeople: [
      { name: "Виталий Бианки", nameEn: "Vitaly Bianki", fame: "Children's writer and naturalist who wrote about Arctic wildlife.", wiki: "https://en.wikipedia.org/wiki/Vitaly_Bianki" },
      { name: "Николай Лунин", nameEn: "Nikolai Lunin", fame: "Soviet submarine commander, Hero of the Soviet Union, served in the Northern Fleet.", wiki: "https://en.wikipedia.org/wiki/Nikolai_Lunin" }
    ]
  },
  {
    name: "Владивосток", nameEn: "Vladivostok",
    image: "", wiki: "https://en.wikipedia.org/wiki/Vladivostok",
    colors: { sky: "#1a2a3a", ground: "#4a5a4a", accent: "#4a8aaa" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      drawBirds(ctx, w*0.2, h*0.1, 4);
      // Golden Horn Bay
      ctx.fillStyle = "#2a4a6a"; ctx.fillRect(0, g-10, w, 22);
      // Hills
      ctx.fillStyle = "#4a5a3a";
      ctx.beginPath(); ctx.moveTo(0, g-5); ctx.quadraticCurveTo(w*0.15, g-40, w*0.3, g-12);
      ctx.quadraticCurveTo(w*0.5, g-35, w*0.7, g-8); ctx.lineTo(w*0.7, g); ctx.lineTo(0, g); ctx.fill();
      // Russky Bridge (cable-stayed)
      ctx.fillStyle = "#c0c0c0";
      ctx.fillRect(w*0.3, g-130, 5, 118); ctx.fillRect(w*0.7, g-130, 5, 118);
      ctx.strokeStyle = "#aaa"; ctx.lineWidth = 0.8;
      for (let i=0;i<10;i++) { ctx.beginPath(); ctx.moveTo(w*0.325, g-125); ctx.lineTo(w*0.08+i*w*0.045, g-12); ctx.stroke(); }
      for (let i=0;i<10;i++) { ctx.beginPath(); ctx.moveTo(w*0.725, g-125); ctx.lineTo(w*0.5+i*w*0.045, g-12); ctx.stroke(); }
      ctx.fillStyle = "#888"; ctx.fillRect(w*0.03, g-18, w*0.94, 6);
      // Buildings on hills
      ctx.fillStyle = "#6a6a5a";
      [[0.05,-38,14,26],[0.12,-45,12,33],[0.2,-42,10,30],[0.8,-35,12,23],[0.88,-40,14,28]].forEach(([x,y,bw,bh]) => {
        ctx.fillRect(w*x, g+y, bw, bh);
        for (let i=0;i<2;i++) drawWindow(ctx, w*x+2+i*6, g+y+5, 4, 5, true);
      });
      // Vladivostok railway station
      ctx.fillStyle = "#d0c0a0"; ctx.fillRect(w*0.4, g-55, w*0.2, 43);
      ctx.fillStyle = "#c0b090"; drawDome(ctx, w*0.5, g-60, 16, 12);
      for (let i=0;i<4;i++) ctx.fillRect(w*0.42+i*w*0.04, g-50, 4, 30);
      ctx.fillStyle = "#b0a080"; ctx.fillRect(w*0.4, g-58, w*0.2, 5);
      // Eagle's Nest hill funicular
      ctx.fillStyle = "#888"; ctx.fillRect(w*0.92, g-60, 2, 48);
      ctx.fillStyle = "#c44"; ctx.fillRect(w*0.91, g-40, 4, 6);
    },
    trivia: [
      "Vladivostok is the eastern terminus of the Trans-Siberian Railway.",
      "The Russky Bridge has the longest cable-stayed span in the world at 1,104 meters.",
      "The city was a closed military zone during the entire Soviet period.",
      "Vladivostok is closer to Tokyo than to Moscow.",
      "The city's name means 'Ruler of the East' in Russian."
    ],
    famousPeople: [
      { name: "Владимир Арсеньев", nameEn: "Vladimir Arsenyev", fame: "Explorer and writer, author of 'Dersu Uzala', explored the Russian Far East.", wiki: "https://en.wikipedia.org/wiki/Vladimir_Arsenyev" },
      { name: "Юл Бриннер", nameEn: "Yul Brynner", fame: "Academy Award-winning actor, star of 'The King and I', born in Vladivostok.", wiki: "https://en.wikipedia.org/wiki/Yul_Brynner" }
    ]
  },
  {
    name: "Сочи", nameEn: "Sochi",
    image: "", wiki: "https://en.wikipedia.org/wiki/Sochi",
    colors: { sky: "#2a3a4a", ground: "#5a7a4a", accent: "#4aaa7a" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      drawBirds(ctx, w*0.4, h*0.08, 3);
      // Black Sea
      ctx.fillStyle = "#2a5a7a"; ctx.fillRect(0, g-8, w*0.55, 28);
      // Beach
      ctx.fillStyle = "#d0c090"; ctx.fillRect(0, g-8, w*0.55, 8);
      // Caucasus mountains
      ctx.fillStyle = "#6a7a6a";
      ctx.beginPath(); ctx.moveTo(w*0.45, g-8); ctx.lineTo(w*0.58, g-80); ctx.lineTo(w*0.7, g-50);
      ctx.lineTo(w*0.82, g-120); ctx.lineTo(w*0.92, g-70); ctx.lineTo(w, g-90); ctx.lineTo(w, g); ctx.lineTo(w*0.45, g); ctx.fill();
      ctx.fillStyle = "#fff";
      ctx.beginPath(); ctx.moveTo(w*0.82, g-120); ctx.lineTo(w*0.78, g-95); ctx.lineTo(w*0.86, g-95); ctx.fill();
      ctx.beginPath(); ctx.moveTo(w, g-90); ctx.lineTo(w*0.97, g-72); ctx.lineTo(w*1.03, g-72); ctx.fill();
      // Palm trees (detailed)
      for (let p=0;p<3;p++) {
        const px = w*0.1+p*w*0.12, py = g;
        ctx.fillStyle = "#4a3020"; ctx.fillRect(px-2, py-55, 4, 45);
        ctx.fillStyle = "#2a8a3a";
        for (let a=-3;a<=3;a++) {
          ctx.beginPath(); ctx.moveTo(px, py-55);
          ctx.quadraticCurveTo(px+a*14, py-65, px+a*20, py-48);
          ctx.lineWidth = 2.5; ctx.strokeStyle = "#2a8a3a"; ctx.stroke();
        }
      }
      // Sanatorium building
      ctx.fillStyle = "#e0d8c0"; ctx.fillRect(w*0.35, g-50, w*0.18, 38);
      for (let i=0;i<3;i++) for (let j=0;j<2;j++) drawWindow(ctx, w*0.36+i*w*0.05, g-45+j*14, 6, 8, true);
      ctx.fillStyle = "#c0b8a0"; ctx.fillRect(w*0.35, g-53, w*0.18, 5);
      // Olympic rings (subtle)
      ctx.strokeStyle = "rgba(200,168,48,0.3)"; ctx.lineWidth = 1.5;
      const ox = w*0.6, oy = g-45;
      for (let i=0;i<5;i++) { ctx.beginPath(); ctx.arc(ox+i*8, oy+(i%2)*4, 5, 0, Math.PI*2); ctx.stroke(); }
      // Ski lift cables
      ctx.strokeStyle = "#888"; ctx.lineWidth = 0.5;
      ctx.beginPath(); ctx.moveTo(w*0.65, g-50); ctx.lineTo(w*0.9, g-110); ctx.stroke();
    },
    trivia: [
      "Sochi was the Soviet Union's most popular beach resort destination.",
      "Stalin's personal dacha in Sochi is now a museum open to visitors.",
      "Sochi hosted the 2014 Winter Olympics despite its subtropical climate.",
      "The city stretches 145 km along the Black Sea coast.",
      "Sochi's climate allows both skiing and swimming on the same day."
    ],
    famousPeople: [
      { name: "Евгений Кафельников", nameEn: "Yevgeny Kafelnikov", fame: "Tennis champion, Olympic gold medalist, grew up in Sochi.", wiki: "https://en.wikipedia.org/wiki/Yevgeny_Kafelnikov" },
      { name: "Виктор Цой", nameEn: "Viktor Tsoi", fame: "Rock musician, leader of the band Kino, cultural icon of Soviet youth. Died near Sochi.", wiki: "https://en.wikipedia.org/wiki/Viktor_Tsoi" }
    ]
  },
  {
    name: "Севастополь", nameEn: "Sevastopol",
    image: "", wiki: "https://en.wikipedia.org/wiki/Sevastopol",
    colors: { sky: "#2a2a3a", ground: "#6a6a5a", accent: "#4a6a8a" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      drawBirds(ctx, w*0.5, h*0.1, 4);
      // Black Sea harbor
      ctx.fillStyle = "#2a4a6a"; ctx.fillRect(0, g-12, w, 24);
      // Monument to Sunken Ships
      ctx.fillStyle = "#808080"; ctx.fillRect(w*0.42, g-85, 5, 63);
      ctx.fillStyle = "#a0a090"; ctx.fillRect(w*0.38, g-22, 14, 8);
      ctx.fillStyle = "#c8a830";
      ctx.beginPath(); ctx.moveTo(w*0.4, g-85); ctx.lineTo(w*0.445, g-100); ctx.lineTo(w*0.49, g-85); ctx.fill();
      // Eagle
      ctx.fillStyle = "#c8a830"; ctx.beginPath(); ctx.arc(w*0.445, g-96, 5, 0, Math.PI*2); ctx.fill();
      ctx.beginPath(); ctx.moveTo(w*0.44, g-96); ctx.lineTo(w*0.43, g-100); ctx.lineTo(w*0.45, g-96); ctx.fill();
      // Panorama Museum (round building)
      ctx.fillStyle = "#d0c8b0";
      ctx.beginPath(); ctx.arc(w*0.75, g-35, 28, Math.PI, 0); ctx.fill();
      ctx.fillRect(w*0.75-28, g-35, 56, 23);
      for (let i=0;i<5;i++) drawWindow(ctx, w*0.73-16+i*10, g-28, 5, 8, false);
      ctx.fillStyle = "#c0b8a0"; drawDome(ctx, w*0.75, g-38, 20, 10);
      // Naval ships
      ctx.fillStyle = "#555";
      ctx.fillRect(w*0.08, g-18, 35, 10); ctx.fillRect(w*0.15, g-24, 4, 10);
      ctx.fillRect(w*0.22, g-15, 28, 8); ctx.fillRect(w*0.28, g-22, 3, 10);
      ctx.fillStyle = "#888"; ctx.fillRect(w*0.1, g-14, 8, 3);
      // Grafskaya Wharf
      ctx.fillStyle = "#e0d8c0"; ctx.fillRect(w*0.52, g-50, w*0.12, 38);
      for (let i=0;i<3;i++) ctx.fillRect(w*0.53+i*w*0.035, g-45, 4, 28);
      ctx.fillStyle = "#d0c8b0"; ctx.fillRect(w*0.52, g-53, w*0.12, 5);
      // Chersonesus ruins
      ctx.fillStyle = "#b0a890";
      ctx.fillRect(w*0.02, g-40, 8, 28); ctx.fillRect(w*0.06, g-35, 6, 23); ctx.fillRect(w*0.1, g-30, 5, 18);
      // Trees
      for (let i=0;i<3;i++) drawTree(ctx, w*0.65+i*12, g, 18, 'round');
    },
    trivia: [
      "Sevastopol was besieged twice: during the Crimean War and WWII.",
      "The Monument to Sunken Ships is the city's most iconic landmark.",
      "Sevastopol was home to the Soviet Black Sea Fleet.",
      "The city was designated a 'Hero City' for its WWII defense.",
      "The Panorama Museum depicts the first siege of Sevastopol in 1854-55."
    ],
    famousPeople: [
      { name: "Павел Нахимов", nameEn: "Pavel Nakhimov", fame: "Admiral who led the defense of Sevastopol during the Crimean War.", wiki: "https://en.wikipedia.org/wiki/Pavel_Nakhimov" },
      { name: "Людмила Павличенко", nameEn: "Lyudmila Pavlichenko", fame: "WWII sniper with 309 confirmed kills, defended Sevastopol, Hero of the Soviet Union.", wiki: "https://en.wikipedia.org/wiki/Lyudmila_Pavlichenko" }
    ]
  },
  {
    name: "Харьков", nameEn: "Kharkiv",
    image: "", wiki: "https://en.wikipedia.org/wiki/Kharkiv",
    colors: { sky: "#2a2a3a", ground: "#5a5a4a", accent: "#7a5a3a" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      // Freedom Square (huge)
      ctx.fillStyle = "#7a7a6a"; ctx.fillRect(w*0.1, g-8, w*0.75, 6);
      // Derzhprom (Gosprom) - constructivist masterpiece
      ctx.fillStyle = "#7a7a7a";
      ctx.fillRect(w*0.28, g-95, w*0.13, 83); ctx.fillRect(w*0.44, g-110, w*0.13, 98); ctx.fillRect(w*0.6, g-95, w*0.13, 83);
      // Connecting sky-bridges
      ctx.fillRect(w*0.41, g-65, w*0.03, 8); ctx.fillRect(w*0.57, g-65, w*0.03, 8);
      ctx.fillRect(w*0.41, g-45, w*0.03, 8); ctx.fillRect(w*0.57, g-45, w*0.03, 8);
      // Windows on all three blocks
      for (let b=0;b<3;b++) {
        const bx = [w*0.28,w*0.44,w*0.6][b], bh = [95,110,95][b];
        for (let i=0;i<3;i++) for (let j=0;j<5;j++) drawWindow(ctx, bx+5+i*12, g-bh+12+j*15, 6, 8, (b+i+j)%3===0);
      }
      // Annunciation Cathedral
      ctx.fillStyle = "#c44"; ctx.fillRect(w*0.08, g-65, 22, 53);
      ctx.fillStyle = "#c44"; drawOnionDome(ctx, w*0.08+11, g-75, 10, 15);
      for (let i=0;i<2;i++) drawWindow(ctx, w*0.09+i*8, g-55, 5, 8, true);
      // Mirror Stream fountain
      ctx.fillStyle = "#8ac0e0"; ctx.fillRect(w*0.78, g-20, 16, 8);
      ctx.fillStyle = "#c0c0c0"; ctx.fillRect(w*0.78, g-28, 16, 10);
      ctx.fillStyle = "#aaa";
      ctx.beginPath(); ctx.moveTo(w*0.78, g-28); ctx.lineTo(w*0.786, g-35); ctx.lineTo(w*0.796, g-28); ctx.fill();
      // Trees
      for (let i=0;i<5;i++) drawTree(ctx, w*0.15+i*w*0.04, g, 20, 'round');
      for (let i=0;i<3;i++) drawTree(ctx, w*0.76+i*12, g, 18, 'round');
    },
    trivia: [
      "Kharkiv's Freedom Square is one of the largest city squares in Europe.",
      "The Derzhprom building was the first Soviet skyscraper, built in 1928.",
      "Kharkiv was the first capital of Soviet Ukraine from 1919 to 1934.",
      "The city is a major center for science and education with over 30 universities.",
      "Kharkiv's metro was the second to open in Ukraine after Kyiv's."
    ],
    famousPeople: [
      { name: "Клавдия Шульженко", nameEn: "Klavdiya Shulzhenko", fame: "Singer, People's Artist of the USSR, famous for wartime song 'Blue Kerchief'.", wiki: "https://en.wikipedia.org/wiki/Klavdiya_Shulzhenko" },
      { name: "Лев Ландау", nameEn: "Lev Landau", fame: "Nobel Prize-winning physicist, worked at Kharkiv's Ukrainian Institute of Physics.", wiki: "https://en.wikipedia.org/wiki/Lev_Landau" },
      { name: "Гнат Хоткевич", nameEn: "Hnat Khotkevych", fame: "Ukrainian writer, bandura player, and cultural figure from Kharkiv.", wiki: "https://en.wikipedia.org/wiki/Hnat_Khotkevych" }
    ]
  },
  {
    name: "Львов", nameEn: "Lviv",
    image: "", wiki: "https://en.wikipedia.org/wiki/Lviv",
    colors: { sky: "#2a2a3a", ground: "#6a5a4a", accent: "#5a8a5a" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      ctx.fillStyle = "rgba(160,160,140,0.1)"; drawCloud(ctx, w*0.6, h*0.08, 22);
      drawBirds(ctx, w*0.3, h*0.12, 3);
      // Old town rooftops (detailed)
      const roofColors = ["#6a3020","#7a4030","#5a2a18","#8a5040","#6a3828","#7a3a28","#5a3020"];
      for (let i=0;i<7;i++) {
        const bh = 45+i*7; ctx.fillStyle = "#d0c0a0";
        ctx.fillRect(w*0.04+i*w*0.11, g-bh, w*0.09, bh);
        ctx.fillStyle = roofColors[i];
        ctx.beginPath(); ctx.moveTo(w*0.04+i*w*0.11, g-bh); ctx.lineTo(w*0.04+i*w*0.11+w*0.045, g-bh-16);
        ctx.lineTo(w*0.04+i*w*0.11+w*0.09, g-bh); ctx.fill();
        // Windows
        for (let j=0;j<2;j++) for (let k=0;k<2;k++) drawWindow(ctx, w*0.05+i*w*0.11+j*12, g-bh+10+k*14, 5, 8, (i+j+k)%3===0);
        // Dormers
        if (i%2===0) {
          ctx.fillStyle = roofColors[i];
          ctx.fillRect(w*0.06+i*w*0.11, g-bh-8, 8, 10);
          drawWindow(ctx, w*0.06+i*w*0.11+1, g-bh-6, 5, 6, true);
        }
      }
      // Town Hall tower
      ctx.fillStyle = "#c0b8a0"; ctx.fillRect(w*0.42, g-120, 12, 88);
      ctx.fillStyle = "#4a6a4a";
      ctx.beginPath(); ctx.moveTo(w*0.42, g-120); ctx.lineTo(w*0.48, g-142); ctx.lineTo(w*0.54, g-120); ctx.fill();
      // Clock
      ctx.fillStyle = "#fff"; ctx.beginPath(); ctx.arc(w*0.48, g-100, 5, 0, Math.PI*2); ctx.fill();
      ctx.fillStyle = "#222"; ctx.beginPath(); ctx.arc(w*0.48, g-100, 4, 0, Math.PI*2); ctx.fill();
      // Opera House
      ctx.fillStyle = "#e0d8c0"; ctx.fillRect(w*0.6, g-60, w*0.28, 48);
      ctx.fillStyle = "#c0b8a0"; drawDome(ctx, w*0.74, g-65, 18, 14);
      for (let i=0;i<5;i++) ctx.fillRect(w*0.62+i*w*0.05, g-55, 4, 35);
      for (let i=0;i<4;i++) drawWindow(ctx, w*0.63+i*w*0.05+5, g-50, 5, 8, i%2===0);
      ctx.fillStyle = "#d0c8b0"; ctx.fillRect(w*0.6, g-63, w*0.28, 5);
      // Statue in front
      ctx.fillStyle = "#808080"; ctx.fillRect(w*0.73, g-18, 3, 6);
      ctx.beginPath(); ctx.arc(w*0.745, g-20, 3, 0, Math.PI*2); ctx.fill();
      // Trees
      for (let i=0;i<3;i++) drawTree(ctx, w*0.56+i*10, g, 18, 'round');
    },
    trivia: [
      "Lviv's entire old town is a UNESCO World Heritage Site.",
      "The city was part of Poland, Austria-Hungary, and the USSR before Ukrainian independence.",
      "Lviv is considered the coffee capital of Ukraine.",
      "The Lviv Opera House is one of the most beautiful in Europe.",
      "The city was founded in 1256 by King Daniel of Galicia."
    ],
    famousPeople: [
      { name: "Стефан Банах", nameEn: "Stefan Banach", fame: "Mathematician, founder of functional analysis, worked at Lviv University.", wiki: "https://en.wikipedia.org/wiki/Stefan_Banach" },
      { name: "Леопольд фон Захер-Мазох", nameEn: "Leopold von Sacher-Masoch", fame: "Writer born in Lviv, whose name gave rise to the term 'masochism'.", wiki: "https://en.wikipedia.org/wiki/Leopold_von_Sacher-Masoch" },
      { name: "Соломия Крушельницкая", nameEn: "Solomiya Krushelnytska", fame: "World-renowned opera soprano, performed at La Scala and the Met.", wiki: "https://en.wikipedia.org/wiki/Solomiya_Krushelnytska" }
    ]
  },
  {
    name: "Магнитогорск", nameEn: "Magnitogorsk",
    image: "", wiki: "https://en.wikipedia.org/wiki/Magnitogorsk",
    colors: { sky: "#1a1a2a", ground: "#4a4a3a", accent: "#c06030" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      // Ural river
      ctx.fillStyle = "#3a4a5a"; ctx.fillRect(0, g-8, w, 16);
      // Magnitnaya mountain
      ctx.fillStyle = "#5a4a3a";
      ctx.beginPath(); ctx.moveTo(w*0.65, g); ctx.lineTo(w*0.78, g-60); ctx.lineTo(w*0.92, g); ctx.fill();
      ctx.fillStyle = "#4a3a2a";
      ctx.beginPath(); ctx.moveTo(w*0.7, g-10); ctx.lineTo(w*0.78, g-45); ctx.lineTo(w*0.86, g-10); ctx.fill();
      // Steel mill (massive, detailed)
      ctx.fillStyle = "#5a5a5a"; ctx.fillRect(w*0.2, g-75, w*0.42, 63);
      ctx.fillStyle = "#4a4a4a";
      [[0.25,110],[0.33,130],[0.42,120],[0.5,105]].forEach(([x,ht]) => {
        ctx.fillRect(w*x-4, g-ht, 8, ht-12);
        // Smoke
        ctx.fillStyle = "#8a8a8a"; ctx.globalAlpha = 0.35;
        ctx.beginPath(); ctx.arc(w*x, g-ht-8, 8, 0, Math.PI*2); ctx.fill();
        ctx.beginPath(); ctx.arc(w*x+6, g-ht-18, 10, 0, Math.PI*2); ctx.fill();
        ctx.beginPath(); ctx.arc(w*x+2, g-ht-28, 12, 0, Math.PI*2); ctx.fill();
        ctx.globalAlpha = 1; ctx.fillStyle = "#4a4a4a";
      });
      // Glow from furnaces
      ctx.fillStyle = "rgba(255,100,20,0.15)";
      ctx.fillRect(w*0.25, g-70, w*0.3, 20);
      // Rear to Front monument
      ctx.fillStyle = "#808080"; ctx.fillRect(w*0.1, g-65, 5, 53);
      ctx.beginPath(); ctx.arc(w*0.125, g-70, 7, 0, Math.PI*2); ctx.fill();
      // Sword being passed
      ctx.save(); ctx.translate(w*0.125, g-65); ctx.rotate(-0.3);
      ctx.fillRect(-1, -20, 2, 20); ctx.restore();
      // Worker housing
      ctx.fillStyle = "#6a6a5a"; ctx.fillRect(w*0.02, g-40, w*0.08, 28);
      for (let i=0;i<2;i++) for (let j=0;j<2;j++) drawWindow(ctx, w*0.025+i*8, g-35+j*10, 4, 5, true);
    },
    trivia: [
      "Magnitogorsk was built from scratch in the 1930s as a Soviet steel city.",
      "The city's steel mill was one of the largest in the world.",
      "Magnitogorsk produced much of the steel used in Soviet WWII tanks.",
      "The Rear to Front monument symbolizes the city's wartime contribution.",
      "Mount Magnitnaya, rich in iron ore, gave the city its name."
    ],
    famousPeople: [
      { name: "Борис Ручьёв", nameEn: "Boris Ruchyov", fame: "Poet who chronicled the construction of Magnitogorsk, laureate of the State Prize.", wiki: "https://en.wikipedia.org/wiki/Boris_Ruchyov" },
      { name: "Муса Джалиль", nameEn: "Musa Jalil", fame: "Tatar poet who worked in Magnitogorsk before WWII, Hero of the Soviet Union.", wiki: "https://en.wikipedia.org/wiki/Musa_Jalil" }
    ]
  },
  {
    name: "Норильск", nameEn: "Norilsk",
    image: "", wiki: "https://en.wikipedia.org/wiki/Norilsk",
    colors: { sky: "#0a0a1a", ground: "#3a3a3a", accent: "#6a7a8a" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      // Tundra + snow
      ctx.fillStyle = "#4a4a3a"; ctx.fillRect(0, g-5, w, 10);
      ctx.fillStyle = "#d0d8e0"; ctx.fillRect(0, g+3, w, h-g-3);
      // Snow patches
      ctx.fillStyle = "#c8d0d8";
      for (let i=0;i<8;i++) { ctx.beginPath(); ctx.ellipse(w*0.1+i*w*0.11, g-2, 15, 4, 0, 0, Math.PI*2); ctx.fill(); }
      // Nickel smelter (massive)
      ctx.fillStyle = "#5a5a5a"; ctx.fillRect(w*0.3, g-85, w*0.35, 73);
      ctx.fillStyle = "#4a4a4a";
      ctx.fillRect(w*0.38, g-125, 8, 48); ctx.fillRect(w*0.5, g-118, 8, 40); ctx.fillRect(w*0.58, g-110, 6, 32);
      // Smoke plumes
      ctx.fillStyle = "#7a7a7a"; ctx.globalAlpha = 0.3;
      [[0.42,-135,14],[0.54,-128,12],[0.61,-118,10]].forEach(([x,y,r]) => {
        ctx.beginPath(); ctx.arc(w*x, g+y, r, 0, Math.PI*2); ctx.fill();
        ctx.beginPath(); ctx.arc(w*x+5, g+y-12, r+3, 0, Math.PI*2); ctx.fill();
      });
      ctx.globalAlpha = 1;
      // Colorful Soviet apartment blocks
      const blockColors = [["#4a8aaa","#5a9aba"],["#aa6a4a","#ba7a5a"],["#6a9a6a","#7aaa7a"],["#8a6a8a","#9a7a9a"]];
      for (let i=0;i<4;i++) {
        ctx.fillStyle = blockColors[i][0]; ctx.fillRect(w*0.05+i*w*0.06, g-55-i*3, w*0.05, 43+i*3);
        ctx.fillStyle = blockColors[i][1]; ctx.fillRect(w*0.05+i*w*0.06, g-55-i*3, w*0.05, 4);
        for (let j=0;j<2;j++) for (let k=0;k<3;k++) drawWindow(ctx, w*0.052+i*w*0.06+j*8, g-50-i*3+k*12, 4, 6, (i+j+k)%2===0);
      }
      // More blocks on right
      for (let i=0;i<3;i++) {
        ctx.fillStyle = blockColors[i][0]; ctx.fillRect(w*0.72+i*w*0.08, g-48-i*4, w*0.06, 36+i*4);
        ctx.fillStyle = blockColors[i][1]; ctx.fillRect(w*0.72+i*w*0.08, g-48-i*4, w*0.06, 4);
        for (let j=0;j<2;j++) for (let k=0;k<2;k++) drawWindow(ctx, w*0.725+i*w*0.08+j*10, g-42-i*4+k*12, 5, 6, true);
      }
    },
    trivia: [
      "Norilsk is the northernmost city with over 100,000 people.",
      "The city was built largely by Gulag prisoners in the 1930s-50s.",
      "Norilsk is one of the most polluted cities on Earth due to nickel smelting.",
      "Temperatures can drop below -50°C in winter.",
      "The city was closed to foreigners until 2001."
    ],
    famousPeople: [
      { name: "Николай Урванцев", nameEn: "Nikolai Urvantsev", fame: "Geologist who discovered the Norilsk nickel deposits, later imprisoned in the Gulag he helped create.", wiki: "https://en.wikipedia.org/wiki/Nikolai_Urvantsev" },
      { name: "Лев Гумилёв", nameEn: "Lev Gumilev", fame: "Historian and ethnologist, imprisoned in Norilsk Gulag, son of poets Akhmatova and Gumilev.", wiki: "https://en.wikipedia.org/wiki/Lev_Gumilev" }
    ]
  },
  {
    name: "Иркутск", nameEn: "Irkutsk",
    image: "", wiki: "https://en.wikipedia.org/wiki/Irkutsk",
    colors: { sky: "#1a2a3a", ground: "#4a5a4a", accent: "#4a8aaa" },
    landmarks: (ctx, w, h) => {
      const g = h * 0.65;
      drawBirds(ctx, w*0.6, h*0.1, 3);
      // Lake Baikal
      ctx.fillStyle = "#2a5a8a"; ctx.fillRect(0, g-12, w, 24);
      // Ice patterns
      ctx.strokeStyle = "#8ac0e0"; ctx.lineWidth = 0.5; ctx.globalAlpha = 0.25;
      for (let i=0;i<8;i++) { ctx.beginPath(); ctx.moveTo(w*0.08+i*w*0.1, g-10); ctx.lineTo(w*0.12+i*w*0.1, g+6); ctx.stroke(); }
      ctx.globalAlpha = 1;
      // Siberian wooden houses (izba) - detailed
      const izbaColors = ["#8a6a40","#7a5a30","#9a7a50","#6a4a20"];
      for (let i=0;i<4;i++) {
        ctx.fillStyle = izbaColors[i]; ctx.fillRect(w*0.05+i*w*0.1, g-50-i*3, w*0.08, 38+i*3);
        ctx.fillStyle = "#5a3a18";
        ctx.beginPath(); ctx.moveTo(w*0.05+i*w*0.1, g-50-i*3); ctx.lineTo(w*0.05+i*w*0.1+w*0.04, g-65-i*3);
        ctx.lineTo(w*0.05+i*w*0.1+w*0.08, g-50-i*3); ctx.fill();
        // Carved window frames
        for (let j=0;j<2;j++) {
          ctx.fillStyle = "#4a8ac0"; ctx.fillRect(w*0.06+i*w*0.1+j*12, g-42-i*3, 6, 8);
          ctx.strokeStyle = "#c8a830"; ctx.lineWidth = 0.5; ctx.strokeRect(w*0.058+i*w*0.1+j*12, g-44-i*3, 10, 12);
        }
      }
      // Church of the Saviour
      ctx.fillStyle = "#e0d0b0"; ctx.fillRect(w*0.52, g-75, 28, 53);
      ctx.fillStyle = "#fff"; drawOnionDome(ctx, w*0.52+14, g-85, 12, 16);
      drawOnionDome(ctx, w*0.52+5, g-78, 7, 10); drawOnionDome(ctx, w*0.52+23, g-78, 7, 10);
      for (let i=0;i<3;i++) drawWindow(ctx, w*0.53+i*8, g-65, 5, 8, true);
      // Angara River outlet
      ctx.fillStyle = "#3a6a8a"; ctx.fillRect(w*0.45, g-8, w*0.12, 14);
      // Taiga forest
      for (let i=0;i<10;i++) drawTree(ctx, w*0.68+i*w*0.03, g-2-Math.sin(i)*3, 22+i%3*5, 'pine');
      // Decembrist house museum
      ctx.fillStyle = "#6a8a6a"; ctx.fillRect(w*0.42, g-45, w*0.08, 33);
      ctx.fillStyle = "#5a7a5a"; ctx.fillRect(w*0.42, g-48, w*0.08, 5);
      drawWindow(ctx, w*0.43, g-38, 5, 8, true); drawWindow(ctx, w*0.47, g-38, 5, 8, true);
    },
    trivia: [
      "Irkutsk is the gateway to Lake Baikal, the world's deepest and oldest lake.",
      "Lake Baikal contains 20% of the world's unfrozen fresh water.",
      "Irkutsk was a place of exile for political prisoners, including Decembrists.",
      "The city is known as the 'Paris of Siberia' for its ornate architecture.",
      "The Trans-Siberian Railway made Irkutsk a major stop between Moscow and the Pacific."
    ],
    famousPeople: [
      { name: "Александр Колчак", nameEn: "Alexander Kolchak", fame: "White Army leader during the Russian Civil War, executed in Irkutsk in 1920.", wiki: "https://en.wikipedia.org/wiki/Alexander_Kolchak" },
      { name: "Леонид Гайдай", nameEn: "Leonid Gaidai", fame: "Film director of beloved Soviet comedies like 'Operation Y' and 'The Diamond Arm'.", wiki: "https://en.wikipedia.org/wiki/Leonid_Gaidai" },
      { name: "Валентин Распутин", nameEn: "Valentin Rasputin", fame: "Writer known for 'Farewell to Matyora', chronicler of Siberian village life.", wiki: "https://en.wikipedia.org/wiki/Valentin_Rasputin" }
    ]
  },
];
