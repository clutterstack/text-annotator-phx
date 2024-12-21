/**
Copied from David Bernheisel
https://bernheisel.com/blog/moving-blog
*/
import hljs from '../../vendor/highlight.js/lib/core';

import elixir from '../../vendor/highlight.js/lib/languages/elixir';
import javascript from '../../vendor/highlight.js/lib/languages/javascript';
import shell from '../../vendor/highlight.js/lib/languages/shell';
import bash from '../../vendor/highlight.js/lib/languages/bash';
import erb from '../../vendor/highlight.js/lib/languages/erb';
import ruby from '../../vendor/highlight.js/lib/languages/ruby';
import vim from '../../vendor/highlight.js/lib/languages/vim';
import yaml from '../../vendor/highlight.js/lib/languages/yaml';
import json from '../../vendor/highlight.js/lib/languages/json';
import diff from '../../vendor/highlight.js/lib/languages/diff';
import xml from '../../vendor/highlight.js/lib/languages/xml';


export const Highlighter = {

  mounted() {

    // Yeah, this isn't very sexy, but I'm trying to keep the bundle small
    // by only opting into languages I use in blog posts.
    hljs.registerLanguage('javascript', javascript);
    hljs.registerLanguage('shell', shell);
    hljs.registerLanguage('bash', bash);
    hljs.registerLanguage('elixir', elixir);
    hljs.registerLanguage('eex', erb);
    hljs.registerLanguage('ruby', ruby);
    hljs.registerLanguage('vim', vim);
    hljs.registerLanguage('yaml', yaml);
    hljs.registerLanguage('json', json);
    hljs.registerLanguage('diff', diff);
    hljs.registerLanguage('html', xml);

    function highlightAll(where = document) {
      where.querySelectorAll('pre code').forEach((el) => {
        console.log("Got a class: " + el.classList)
        const languageClass = Array.from(el.classList).find(className => 
          className.startsWith('language-')
        );
        const lang = languageClass?.replace('language-', '');
        console.log("Got a lang: " + lang)
        if (lang != null) {
          const { value: value } = hljs.highlight(el.innerText, {language: lang, ignoreIllegals: true});
          el.innerHTML = value;
          // hljs.highlightElement(el);
        }
      });
    }

    // Highlight code blocks on page load
    highlightAll();
    }
  };