const nav = document.querySelector(".site-nav");
const menuTrigger = document.querySelector(".menu-trigger");

menuTrigger?.addEventListener("click", () => {
  const isOpen = nav.classList.toggle("open");
  menuTrigger.setAttribute("aria-expanded", String(isOpen));
});

nav?.addEventListener("click", event => {
  if (event.target.closest("a")) {
    nav.classList.remove("open");
    menuTrigger?.setAttribute("aria-expanded", "false");
  }
});

const reveals = document.querySelectorAll(".reveal");
if (reveals.length) {
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add("visible");
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: .1 });

  reveals.forEach(element => observer.observe(element));
}
