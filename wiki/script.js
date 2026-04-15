// Nav scroll effect
const nav = document.querySelector('.nav');
window.addEventListener('scroll', () => {
  nav.classList.toggle('scrolled', window.scrollY > 20);
});

// Mobile hamburger
const hamburger = document.querySelector('.nav-hamburger');
const navLinks = document.querySelector('.nav-links');
const MENU_ICON = 'M3 12h18M3 6h18M3 18h18';
const CLOSE_ICON = 'M18 6L6 18M6 6l12 12';
const navIconPath = hamburger ? hamburger.querySelector('path') : null;

function setMobileMenuOpen(isOpen) {
  if (!navLinks || !navIconPath) return;
  navLinks.classList.toggle('open', isOpen);
  navIconPath.setAttribute('d', isOpen ? CLOSE_ICON : MENU_ICON);
}

if (hamburger) {
  hamburger.addEventListener('click', () => {
    const isOpen = navLinks.classList.contains('open');
    setMobileMenuOpen(!isOpen);
  });
}

// Active nav link tracking
const sections = document.querySelectorAll('.section[id]');
const navAnchors = document.querySelectorAll('.nav-links a[href^="#"]');

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        navAnchors.forEach((a) => a.classList.remove('active'));
        const active = document.querySelector(`.nav-links a[href="#${entry.target.id}"]`);
        if (active) active.classList.add('active');
      }
    });
  },
  { rootMargin: '-30% 0px -60% 0px' }
);

sections.forEach((s) => observer.observe(s));

// Close mobile nav on link click
navAnchors.forEach((a) => {
  a.addEventListener('click', () => {
    setMobileMenuOpen(false);
  });
});

// Copy button
document.querySelectorAll('.code-copy').forEach((btn) => {
  btn.addEventListener('click', () => {
    const code = btn.closest('.code-section').querySelector('pre');
    const text = code.textContent;
    navigator.clipboard.writeText(text).then(() => {
      const orig = btn.textContent;
      btn.textContent = 'Copied!';
      btn.style.color = 'var(--accent-3)';
      btn.style.borderColor = 'var(--accent-3)';
      setTimeout(() => {
        btn.textContent = orig;
        btn.style.color = '';
        btn.style.borderColor = '';
      }, 2000);
    });
  });
});

// Scroll Progress Bar
const progressBar = document.querySelector('.scroll-progress');
window.addEventListener('scroll', () => {
  const winScroll = document.body.scrollTop || document.documentElement.scrollTop;
  const height = document.documentElement.scrollHeight - document.documentElement.clientHeight;
  const scrolled = (winScroll / height) * 100;
  if (progressBar) progressBar.style.width = scrolled + '%';
});

// Reveal Animations Initialization
document.addEventListener('DOMContentLoaded', () => {
  // Auto-add reveal class to elements
  const elementsToReveal = document.querySelectorAll('.section-header, .mermaid-wrap, .table-wrap, .code-section, .feature-card, .topic-card, .cost-card, .file-tree');
  elementsToReveal.forEach((el) => {
    el.classList.add('reveal');
  });

  // Hero elements get special treatment to reveal on load
  const heroElements = document.querySelectorAll('.hero-badge, .hero h1, .hero-sub, .hero-actions');
  heroElements.forEach((el, index) => {
    el.classList.add('reveal');
    setTimeout(() => {
      el.classList.add('active');
    }, index * 150 + 100);
  });

  revealElements();
});

function revealElements() {
  const reveals = document.querySelectorAll('.reveal:not(.active)');
  const windowHeight = window.innerHeight;
  const elementVisible = 80; // trigger point

  reveals.forEach((reveal) => {
    const elementTop = reveal.getBoundingClientRect().top;
    if (elementTop < windowHeight - elementVisible) {
      reveal.classList.add('active');
    }
  });
}
window.addEventListener('scroll', revealElements);
