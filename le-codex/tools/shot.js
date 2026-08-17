// Captures de contrôle du rendu. Usage : node shot.js <url> <fichier> [largeur] [scrollY]
const puppeteer = require("puppeteer");

const [url, out, width = "1440", scrollY = "0"] = process.argv.slice(2);

(async () => {
  const browser = await puppeteer.launch({
    executablePath: "/usr/bin/chromium-browser",
    args: ["--no-sandbox", "--disable-gpu", "--hide-scrollbars"],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: Number(width), height: 900, deviceScaleFactor: 1 });
  await page.goto(url, { waitUntil: "networkidle2", timeout: 60000 });

  // Les apparitions au scroll masqueraient le contenu : on les force.
  await page.evaluate(() => {
    document.querySelectorAll(".reveal").forEach(element => element.classList.add("visible"));
  });
  await new Promise(resolve => setTimeout(resolve, 1200));

  if (scrollY && scrollY !== "0") {
    await page.evaluate(target => {
      const y = Number(target);
      if (Number.isFinite(y)) return window.scrollTo(0, y);
      const node = document.querySelector(target);
      if (node) window.scrollTo(0, node.getBoundingClientRect().top + window.scrollY - 80);
    }, scrollY);
    await new Promise(resolve => setTimeout(resolve, 2000));
    await page.screenshot({ path: out });
  } else {
    await page.screenshot({ path: out, fullPage: true });
  }

  console.log("ok " + out);
  await browser.close();
})();
