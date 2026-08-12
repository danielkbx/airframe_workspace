(() => {
  "use strict";

  document.documentElement.classList.add("js");

  const navToggle = document.querySelector("[data-nav-toggle]");
  const nav = document.querySelector("[data-site-nav]");
  if (navToggle && nav) {
    const closeNavigation = () => {
      navToggle.setAttribute("aria-expanded", "false");
      nav.classList.remove("is-open");
    };

    navToggle.addEventListener("click", () => {
      const willOpen = navToggle.getAttribute("aria-expanded") !== "true";
      navToggle.setAttribute("aria-expanded", String(willOpen));
      nav.classList.toggle("is-open", willOpen);
    });
    nav.addEventListener("click", (event) => {
      if (event.target.closest("a")) closeNavigation();
    });
    window.addEventListener("resize", () => {
      if (window.matchMedia("(min-width: 801px)").matches) closeNavigation();
    });
  }

  const telemetry = document.querySelectorAll("[data-telemetry]");
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduceMotion || !("IntersectionObserver" in window)) {
    telemetry.forEach((item) => item.classList.add("is-active"));
  } else {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => entry.target.classList.toggle("is-active", entry.isIntersecting));
    }, { rootMargin: "80px 0px", threshold: 0.05 });
    telemetry.forEach((item) => observer.observe(item));
  }

  const dialog = document.querySelector("[data-lightbox]");
  const triggers = Array.from(document.querySelectorAll("[data-lightbox-trigger]"));
  if (!dialog || typeof dialog.showModal !== "function" || triggers.length === 0) return;

  const image = dialog.querySelector("[data-lightbox-image]");
  const caption = dialog.querySelector("[data-lightbox-caption]");
  const count = dialog.querySelector("[data-lightbox-count]");
  const full = dialog.querySelector("[data-lightbox-full]");
  const previous = dialog.querySelector("[data-lightbox-previous]");
  const next = dialog.querySelector("[data-lightbox-next]");
  const close = dialog.querySelector("[data-lightbox-close]");
  let gallery = [];
  let index = 0;
  let returnFocus = null;

  const showImage = (nextIndex) => {
    index = (nextIndex + gallery.length) % gallery.length;
    const trigger = gallery[index];
    const preview = trigger.querySelector("img");
    const url = trigger.href;
    image.src = url;
    image.alt = preview ? preview.alt : "";
    caption.textContent = trigger.dataset.caption || "";
    full.href = url;
    count.textContent = gallery.length > 1 ? `${index + 1} / ${gallery.length}` : "";
    previous.hidden = gallery.length < 2;
    next.hidden = gallery.length < 2;
  };

  triggers.forEach((trigger) => {
    trigger.addEventListener("click", (event) => {
      event.preventDefault();
      const galleryName = trigger.dataset.gallery;
      gallery = galleryName ? triggers.filter((item) => item.dataset.gallery === galleryName) : [trigger];
      index = gallery.indexOf(trigger);
      returnFocus = trigger;
      showImage(index);
      dialog.showModal();
      close.focus();
    });
  });

  previous.addEventListener("click", () => showImage(index - 1));
  next.addEventListener("click", () => showImage(index + 1));
  close.addEventListener("click", () => dialog.close());
  dialog.addEventListener("keydown", (event) => {
    if (event.key === "ArrowLeft" && gallery.length > 1) showImage(index - 1);
    if (event.key === "ArrowRight" && gallery.length > 1) showImage(index + 1);
  });
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) dialog.close();
  });
  dialog.addEventListener("close", () => {
    image.removeAttribute("src");
    if (returnFocus && document.contains(returnFocus)) returnFocus.focus();
  });
})();
