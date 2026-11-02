function insertScript(scriptContent, scriptAttributes = {}) {
    const script = document.createElement('script');
    script.textContent = scriptContent;
    Object.keys(scriptAttributes).forEach(attr => {
        script.setAttribute(attr, scriptAttributes[attr]);
    });
    let head = document.head || document.getElementsByTagName('head')[0];
    if (!head) {
        head = document.createElement('head');
        document.documentElement.insertBefore(head, document.documentElement.firstChild);
    }
    head.appendChild(script);
    return script;
}

const insertedScript = insertScript('', {
    'src': 'https://cloud.umami.is/script.js',
    'data-website-id': 'dc46a7cb-2f30-44d4-a27e-555d56d6869c',
    'defer': ''
});
