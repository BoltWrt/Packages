// Executes the shipped helpers with small DOM/HTTP fixtures, without a router.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = process.argv[2];

function script(relative) {
  const html = fs.readFileSync(path.join(root, relative), 'utf8');
  return [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)]
    .map(match => match[1].replace(/<%=self.normal_list%>/g, '[]').replace(/<%[\s\S]*?%>/g, ''))
    .join('\n');
}
const elements = new Map();
const document = {
  getElementById: id => elements.get(id),
  querySelectorAll: () => [],
  addEventListener: () => {},
};
const context = { document, window: {}, lv_change: () => { throw new Error('missing proxy field accessed'); } };
vm.createContext(context);
vm.runInContext(script('luasrc/view/passwall2/include/shunt_options.htm'), context);
const classes = new Set();
const checkbox = { checked: true };
const wrapper = {
  matches: () => false,
  querySelector: () => checkbox,
  classList: { add: value => classes.add(value), remove: value => classes.delete(value) },
};
elements.set('cbid.table.1._fakedns', wrapper);
context.check_fakedns(1, '_direct');
assert.equal(checkbox.checked, false);
assert(classes.has('shunt_hidden'));
checkbox.checked = true;
context.check_fakedns(1, 'proxy-node');
assert.equal(checkbox.checked, true);
assert(!classes.has('shunt_hidden'));
context.check_fakedns(1, '');
assert.equal(checkbox.checked, false);
assert.doesNotThrow(() => context.check_fakedns(99));
assert.doesNotThrow(() => context.check_proxy_tag(99));

const requests = [];
class Request {
  constructor() { requests.push(this); }
  open(method, url, asynchronous) { Object.assign(this, { method, url, asynchronous }); }
  setRequestHeader(name, value) { this.header = [name, value]; }
  send(body) { this.body = body; }
}
const updates = { document, window: {}, XMLHttpRequest: Request, XHR: { get: () => {} } };
vm.createContext(updates);
vm.runInContext(script('luasrc/view/passwall2/app_update/app_version.htm'), updates);
let result;
updates.postUpdate('/update_xray', { token: 'token & +', file: 'file name' }, (request, json) => { result = json; }, 30);
const request = requests.at(-1);
assert.equal(request.method, 'POST');
assert.equal(request.timeout, 30000);
assert.equal(request.header[1], 'application/x-www-form-urlencoded');
assert.equal(new URLSearchParams(request.body).get('token'), 'token & +');
assert.equal(new URLSearchParams(request.body).get('file'), 'file name');
request.status = 200;
request.responseText = '{"code":0}';
request.onload();
assert.equal(result.code, 0);
request.status = 403;
request.responseText = '<html>Denied</html>';
request.onload();
assert.equal(result, null);

// LuCI resource modules are function bodies, with a top-level return.
for (const name of ['cbi.js', 'func.js', 'node_list_sort.js']) {
  const file = path.join(root, 'htdocs/luci-static/resources/view/passwall2', name);
  new vm.Script('(function() {\n' + fs.readFileSync(file, 'utf8') + '\n})');
}
console.log('PASS browser helpers: checkbox hydration, absent fields, POST/token encoding, rejected responses, resource syntax');
