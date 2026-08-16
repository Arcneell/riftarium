const links = [...document.querySelectorAll(".learn-toc a")];
const chapters = links
  .map(link => document.querySelector(link.getAttribute("href")))
  .filter(Boolean);

if (chapters.length) {
  const spy = new IntersectionObserver(entries => {
    entries
      .filter(entry => entry.isIntersecting)
      .forEach(entry => {
        links.forEach(link => link.classList.toggle("active", link.getAttribute("href") === `#${entry.target.id}`));
      });
  }, { rootMargin: "-92px 0px -70% 0px" });

  chapters.forEach(chapter => spy.observe(chapter));
}
