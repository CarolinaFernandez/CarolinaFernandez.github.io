function applyInitialTheme(themeSwitcher) {
  const theme = window.localStorage.getItem("site-theme");
  if (theme !== null) {
      const htmlTag = $("body");
      htmlTag.attr("data-theme", theme);
  }
  // Select the "opposite" theme when loading to show the other option/icon
  reverseTheme = (theme==undefined?"dark":undefined);
  toggleThemeIcon(themeSwitcher, reverseTheme);
}
function toggleThemeIcon(themeSwitcher, themeName) {
  if (typeof themeName !== typeof undefined && themeName !== false && themeName == "dark") {
    $(themeSwitcher).removeClass("fa-sun");
    $(themeSwitcher).addClass("fa-moon");
    $(themeSwitcher).css("color", "#4652aa");
  } else {
    $(themeSwitcher).removeClass("fa-moon");
    $(themeSwitcher).addClass("fa-sun");
    $(themeSwitcher).css("color", "#f8b856");
  }
}
function toggleTheme(themeSwitcher) {
    const htmlTag = $("body");
    const htmlTagAttr = htmlTag.attr("data-theme");
    // Select the "current" theme when switching to show the other option/icon
    toggleThemeIcon(themeSwitcher, htmlTagAttr);
    if (typeof htmlTagAttr !== typeof undefined && htmlTagAttr !== false) {
      htmlTag.removeAttr("data-theme");
      return window.localStorage.removeItem("site-theme");
    }
    htmlTag.attr("data-theme", "dark");
    window.localStorage.setItem("site-theme", "dark");
}

$(document).ready(function() {
  applyInitialTheme($("a.theme-switcher"));
  $("a.theme-switcher").click(function() {
    toggleTheme($(this));
    return false;
  });
  // Update style and text of the .theme-switcher button in the menu
  // so that it looks like a button and provides text
  $("ul.actions a.theme-switcher").addClass("button large fit");
  $("ul.actions a.theme-switcher").text("Theme switch");
});
