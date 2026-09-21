const assert = require('node:assert/strict');
const test = require('node:test');

const plugin = require('../app.plugin.js');

test('为标准 Expo Podfile 注入私有 Specs 源和 SATagSDK，且可重复执行', () => {
  const source = "platform :ios, '15.1'\n\ntarget 'Demo' do\n  use_expo_modules!\nend\n";
  const once = plugin._internal.updatePodfile(source);
  const twice = plugin._internal.updatePodfile(once);

  assert.equal(once, twice);
  assert.match(once, /^source 'https:\/\/cdn\.cocoapods\.org\/'/);
  assert.match(once, /^source 'http:\/\/172\.20\.30\.113:13000\/StarSdk\/star_ios_pod_specs\.git'/m);
  assert.doesNotMatch(once, /starpodspace/);
  assert.doesNotMatch(once, /github\.com\/CocoaPods\/Specs/);
  assert.match(once, /use_expo_modules!\n  pod 'SATagSDK'/);
});

test('非 Expo 的 Podfile 会把 SATagSDK 注入第一个 target', () => {
  const source = "target 'Demo' do\n  pod 'React-Core'\nend\n";
  const updated = plugin._internal.updatePodfile(source);

  assert.match(updated, /target 'Demo' do\n  pod 'SATagSDK'/);
});

test('没有 target 的 Podfile 明确报错', () => {
  assert.throws(
    () => plugin._internal.updatePodfile("source 'https://cdn.cocoapods.org/'\n"),
    /未找到 iOS target/,
  );
});
