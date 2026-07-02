/**
 * Custom JavaScript for FixIt blog site.
 * @author @Lruihao https://lruihao.cn
 */
class FixItBlog {
  setupThemeSwitch() {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const getCurrentMode = () => document.documentElement.dataset.themeMode || 'auto';
    const isDark = () => {
      const mode = getCurrentMode();
      return mode === 'auto'
        ? mediaQuery.matches
        : mode === 'dark';
    };
    const getNextMode = () => isDark() ? 'light' : 'dark';
    const syncTitle = () => {
      const title = isDark() ? '切换到浅色主题' : '切换到深色主题';
      document.querySelectorAll('.theme-switch').forEach((button) => {
        button.setAttribute('title', title);
        button.setAttribute('aria-label', title);
      });
    };

    document.querySelectorAll('.theme-switch').forEach((button) => {
      button.addEventListener('click', (event) => {
        event.preventDefault();
        event.stopImmediatePropagation();
        window.fixit?.setThemeMode?.(getNextMode());
        syncTitle();
      }, true);
    });

    window.addEventListener('storage', (event) => {
      if (event.key === 'theme-mode') syncTitle();
    });
    mediaQuery.addEventListener('change', syncTitle);

    syncTitle();
  }

  /**
   * say hello
   * you can define your own functions below
   * @returns {FixItBlog}
   */
  hello() {
    console.log('custom.js: Hello FixIt!');
    return this;
  }

  /**
   * initialize
   * @returns {FixItBlog}
   */
  init() {
    this.hello();
    this.setupThemeSwitch();
    return this;
  }
}

/**
 * immediate execution
 */
(() => {
  window.fixitBlog = new FixItBlog();
  // it will be executed when the DOM tree is built
  document.addEventListener('DOMContentLoaded', () => {
    window.fixitBlog.init();
  });
})();
