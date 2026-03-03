// Minimal interactions: tab switching, reveals, real Firebase submission
(() => {
  const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const firebaseConfig = {
    apiKey: 'AIzaSyCHSpjDTATv3pm-zSTkMCtne3BRJJmbeKo',
    authDomain: 'uncharted-club.firebaseapp.com',
    projectId: 'uncharted-club',
    storageBucket: 'uncharted-club.firebasestorage.app',
    messagingSenderId: '585681204894'
  };

  firebase.initializeApp(firebaseConfig);
  const firestore = firebase.firestore();

  // Reveal-on-scroll with reduced motion guard
  const revealElements = document.querySelectorAll('.reveal');
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.25 });

  if (!prefersReduced) {
    revealElements.forEach(el => observer.observe(el));
  } else {
    revealElements.forEach(el => el.classList.add('visible'));
  }

  // Tab switching
  const tabLinks = document.querySelectorAll('.tab-link');
  const tabTargets = document.querySelectorAll('[data-tab-target]');
  const panels = document.querySelectorAll('.tab-panel');

  const showTab = (tabId) => {
    panels.forEach(panel => {
      const isActive = panel.dataset.tab === tabId;
      panel.classList.toggle('active', isActive);
      panel.toggleAttribute('hidden', !isActive);
      if (isActive && prefersReduced) {
        panel.querySelectorAll('.reveal').forEach(el => el.classList.add('visible'));
      }
    });

    tabLinks.forEach(link => {
      const isActive = link.dataset.tabTarget === tabId;
      link.classList.toggle('active', isActive);
      link.setAttribute('aria-selected', String(isActive));
    });
  };

  tabTargets.forEach(link => {
    link.addEventListener('click', (event) => {
      event.preventDefault();
      showTab(link.dataset.tabTarget);
    });
  });

  // CTA buttons that switch tabs
  document.querySelectorAll('[data-switch-to]').forEach(btn => {
    btn.addEventListener('click', () => showTab(btn.dataset.switchTo));
  });

  // Firestore submission with native validation
  const form = document.getElementById('apply-form');
  const submitBtn = document.getElementById('submit-mock');
  const successNote = document.querySelector('.success-note');

  const sanitizeText = (value, maxLength = 500) => {
    return (value || '')
      .toString()
      .replace(/[<>]/g, '')
      .trim()
      .slice(0, maxLength);
  };

  const normalizePhone = (value) => {
    const cleaned = sanitizeText(value, 30).replace(/[^+0-9()\s-]/g, '');
    return cleaned;
  };

  const validEmail = (value) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value);
  const validPhone = (value) => /^[+0-9\s()-]{7,20}$/.test(value);

  const buildPayload = (formData) => {
    const raw = Object.fromEntries(
      Array.from(formData.entries()).map(([key, value]) => [key, sanitizeText(value)])
    );

    const mappedChallenge = sanitizeText(raw.challenge || raw.why, 1200);
    const mappedPhone = normalizePhone(raw.phone || raw.whatsapp || raw.whatsApp);

    const payload = {
      type: 'application',
      fullName: sanitizeText(raw.fullName, 120),
      email: sanitizeText(raw.email, 180).toLowerCase(),
      phone: mappedPhone,
      whatsapp: mappedPhone,
      experience: sanitizeText(raw.experience, 120),
      challenge: mappedChallenge,
      attempts: sanitizeText(raw.attempts, 1200),
      success: sanitizeText(raw.success, 1200),
      commitment: sanitizeText(raw.commitment, 120),
      profile: sanitizeText(raw.profile, 300),
      timezone: sanitizeText(raw.timezone, 80),
      sourcePage: sanitizeText(window.location.pathname, 120),
      submittedAt: firebase.firestore.FieldValue.serverTimestamp()
    };

    if (!payload.fullName || payload.fullName.length < 2) {
      throw new Error('Invalid full name');
    }

    if (!validEmail(payload.email)) {
      throw new Error('Invalid email');
    }

    if (!validPhone(payload.phone)) {
      throw new Error('Invalid phone number');
    }

    if (!payload.challenge || payload.challenge.length < 10) {
      throw new Error('Invalid challenge');
    }

    return payload;
  };

  if (form && submitBtn) {
    submitBtn.addEventListener('click', async () => {
      if (!form.reportValidity()) return;

      submitBtn.disabled = true;
      submitBtn.textContent = 'Submitting...';
      successNote?.setAttribute('hidden', '');

      try {
        const formData = new FormData(form);

        const honeypot = sanitizeText(formData.get('companyWebsite'));
        if (honeypot) {
          form.reset();
          successNote?.removeAttribute('hidden');
          return;
        }

        const payload = buildPayload(formData);

        await firestore.collection('form').add(payload);
        form.reset();
        successNote?.removeAttribute('hidden');
      } catch (error) {
        alert('Submission failed. Please try again in a moment.');
        console.error('Firestore submit error:', error);
      } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Submit Application';
      }
    });
  }
})();
