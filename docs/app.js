const input = document.querySelector('#script-input');
const fileInput = document.querySelector('#script-file');
const button = document.querySelector('#generate-button');
const storyboardBody = document.querySelector('#storyboard-body');
const assetList = document.querySelector('#asset-list');
const status = document.querySelector('#status');

const escapeHtml = (value) => value.replace(/[&<>"']/g, (char) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;'
}[char]));

const unique = (values) => [...new Set(values.filter(Boolean))];

function detectAssets(text) {
  const speakers = [...text.matchAll(/(?:^|\n)\s*([\u4e00-\u9fa5]{2,4})[：:]/g)].map((match) => match[1]);
  const locations = ['大厅', '电梯', '街道', '房间', '屋顶', '办公室', '车站', '教室', '仓库', '走廊'].filter((word) => text.includes(word));
  const props = ['手机', '档案', '雨伞', '透明伞', '检修票', '钥匙', '照片', '信封', '电脑', '手电筒'].filter((word) => text.includes(word));
  return [
    ...unique(speakers).map((name) => ({ type: '角色', name })),
    ...unique(locations).map((name) => ({ type: '场景', name })),
    ...unique(props).map((name) => ({ type: '道具', name }))
  ];
}

function buildShots(text) {
  const beats = text.replace(/\r/g, '').split(/\n+|(?<=[。！？!?])\s*/).map((line) => line.trim()).filter((line) => line.length > 1).slice(0, 12);
  const sizes = ['大全景', '中景', '近景', '特写'];
  return beats.map((beat, index) => ({
    beat,
    duration: Math.max(3, Math.min(8, Math.ceil(beat.length / 9))),
    framing: `${sizes[index % sizes.length]} / ${/忽然|冲|跑|打开|亮起|走进/.test(beat) ? '缓推' : index % 3 === 0 ? '固定' : '轻微跟随'}`
  }));
}

function render() {
  const text = input.value.trim();
  if (!text) {
    status.textContent = '请先输入剧本';
    status.classList.remove('ready');
    input.focus();
    return;
  }
  const shots = buildShots(text);
  const assets = detectAssets(text);
  const totalDuration = shots.reduce((total, shot) => total + shot.duration, 0);
  storyboardBody.innerHTML = shots.map((shot, index) => `<tr><td>${String(index + 1).padStart(2, '0')}</td><td>${shot.duration}s</td><td>${escapeHtml(shot.framing)}</td><td>${escapeHtml(shot.beat)}</td></tr>`).join('');
  const visibleAssets = assets.length ? assets : [{ type: '角色', name: '主角（待确认）' }, { type: '场景', name: '主场景（待确认）' }];
  assetList.innerHTML = visibleAssets.map((asset) => `<span class="asset"><b>${escapeHtml(asset.type)}</b>${escapeHtml(asset.name)}</span>`).join('');
  document.querySelector('#shot-count').textContent = shots.length;
  document.querySelector('#duration').textContent = `${totalDuration}s`;
  document.querySelector('#asset-count').textContent = visibleAssets.length;
  status.textContent = 'READY_FOR_REVIEW';
  status.classList.add('ready');
}

fileInput.addEventListener('change', async () => {
  const [file] = fileInput.files;
  if (!file) return;
  if (file.size > 1024 * 1024) {
    status.textContent = '文件需小于 1 MB';
    status.classList.remove('ready');
    fileInput.value = '';
    return;
  }
  input.value = await file.text();
  status.textContent = `已读取 ${file.name}`;
  status.classList.remove('ready');
});

button.addEventListener('click', render);
