'use strict';
'require baseclass';
'require routertraffic.devices_v031 as Devices';
'require routertraffic.resources_v031 as Resources';
'require fs';
'require routertraffic.livechart_v031 as F50LiveChart';
'require routertraffic.units_v031 as Units';

var STATUS_FILE = '/tmp/f50-traffic/status.json';
var HISTORY_FILE = '/tmp/f50-traffic/history.csv';
var STYLE_FILE = '/www/luci-static/resources/routertraffic/wan.css';
var RETAIN_MS = 305000;
var REFRESH_MS = 1000;

function fmtBytes(value){return Units.fmtBytes(value,2,true);}
function fmtRate(value){return Units.fmtRate(value);}

function kpi(valueId, label) {
	return E('div', { 'class': 'mud-kpi' }, [
		E('b', { 'id': valueId }, '--'),
		E('span', {}, label)
	]);
}

return baseclass.extend({
	title: '',

	load: function() {
		if (this.root && document.documentElement.contains(this.root)) return Promise.resolve(null);
		return Promise.all([
			L.resolveDefault(fs.read(STATUS_FILE), '{}'),
			L.resolveDefault(fs.read(HISTORY_FILE), ''),
			L.resolveDefault(fs.read(STYLE_FILE), ''),
			L.resolveDefault(fs.read('/www/luci-static/resources/routertraffic/style.css'), '')
		]);
	},

	parse: function(raw) {
		try {
			return typeof(raw) === 'string' ? JSON.parse(raw) : (raw || {});
		}
		catch (error) {
			return {};
		}
	},

	loadHistory: function(raw) {
		var self = this;
		if (typeof(raw) !== 'string')
			return;

		raw.trim().split(/\n+/).slice(-320).forEach(function(line) {
			var fields = line.trim().split(/\s+/).map(Number);
			if (fields.length === 3 && fields.every(Number.isFinite))
				self.appendSample(fields[0] * 1000, Math.max(0, fields[1]), Math.max(0, fields[2]));
		});
	},

	appendSample: function(timestamp, download, upload) {
		if (!Number.isFinite(timestamp) || timestamp <= this.lastTimestamp)
			return;

		this.rateTimes.push(timestamp);
		this.dlHistory.push(download);
		this.ulHistory.push(upload);
		this.lastTimestamp = timestamp;

		var cutoff = timestamp - RETAIN_MS;
		while (this.rateTimes.length && this.rateTimes[0] < cutoff) {
			this.rateTimes.shift();
			this.dlHistory.shift();
			this.ulHistory.shift();
		}
	},

	build: function(css) {
		var legacyStyle = document.getElementById('f50flow-style');
		if (legacyStyle)
			legacyStyle.remove();
		var v4Style = document.getElementById('f50-dashboard-v4-style');
		if (v4Style)
			v4Style.remove();

		var root = E('div', { 'class': 'f50-home mud rt-root', 'data-f50-style-version': '7' }, [
			E('div', { 'class': 'mud-card mud-body' }, [
				E('div', { 'class': 'mud-sec' }, [
					E('h3', { 'class': 'f50-traffic-title' }, [
						'流量',
						E('span', { 'id': 'f50-peak-title' }, '今日峰值')
					]),
					E('div', { 'class': 'f50-combined-chart', 'style': 'width:100%' }, [
						E('div', { 'class': 'f50-rate-head' }, [
							E('div', { 'class': 'f50-rate-download' }, [
								E('span', {}, '下载'),
								E('b', { 'id': 'f50-dl' }, '--'),
								E('span', { 'class': 'f50-peak-button', 'aria-label': '今日下载峰值' }, [
									E('b', { 'id': 'f50-peak-download' }, '—')
								])
							]),
							E('div', { 'class': 'f50-rate-upload' }, [
								E('span', {}, '上传'),
								E('b', { 'id': 'f50-ul' }, '--'),
								E('span', { 'class': 'f50-peak-button', 'aria-label': '今日上传峰值' }, [
									E('b', { 'id': 'f50-peak-upload' }, '—')
								])
							])
						]),
						E('div', {
							'id': 'mud-rate-chart',
							'style': 'width:100%;margin:6px 0;touch-action:pan-y'
						}),
						E('div', { 'id': 'f50-rate-detail', 'style': 'display:none;font-size:.75em;margin:4px 0' })
					]),
				]),
				E('section', { 'class': 'mud-sec rt-totals-section' }, [
					E('h3', { 'class': 'f50-today-title' }, [
						'今日流量统计',
						E('span', { 'id': 'f50-today-date' }, '--')
					]),
					E('div', { 'class': 'f50-today-kpis' }, [
						kpi('f50-today-rx', '今日下载'),
						kpi('f50-today-tx', '今日上传'),
						kpi('f50-month-total', '本月累计'),
						kpi('f50-total', '总累计')
					])
				])
			])
		]);
		root.prepend(E('style', { 'data-f50-inline-style': '7' }, css || ''));
		return root;
	},

	setText: function(selector, value) {
		var node = this.root && this.root.querySelector(selector);
		if (node)
			node.textContent = value;
	},

	update: function(raw) {
		var data = this.parse(raw);
		if (!this.root || !data.timestamp)
			return;

		var timestamp = Number(data.timestamp) * 1000;
		var download = Math.max(0, Number(data.rx_rate) || 0);
		var upload = Math.max(0, Number(data.tx_rate) || 0);
		this.appendSample(timestamp, download, upload);

		this.setText('#f50-dl', fmtRate(download));
		this.setText('#f50-ul', fmtRate(upload));
		this.setText('#f50-peak-download', fmtRate(data.peak_rx));
		this.setText('#f50-peak-upload', fmtRate(data.peak_tx));
		this.setText('#f50-today-rx', fmtBytes(Math.max(0, Number(data.daily_rx) || 0)));
		this.setText('#f50-today-tx', fmtBytes(Math.max(0, Number(data.daily_tx) || 0)));
		this.setText('#f50-month-total', fmtBytes((Number(data.month_rx) || 0) + (Number(data.month_tx) || 0)));
		this.setText('#f50-total', fmtBytes((Number(data.total_rx) || 0) + (Number(data.total_tx) || 0)));
		this.setText('#f50-today-date', data.date || '--');
		['#f50-month-total', '#f50-total'].forEach(function(selector) {
			var node = this.root.querySelector(selector);
			if (node) node.title = data.history_partial ? '从可恢复历史起累计；旧版未保存的完整月度和更早历史无法补算' : '从本机开始记录起累计';
		}, this);

		if (this.liveChart)
			this.liveChart.update(this.rateTimes, this.dlHistory, this.ulHistory);
	},

	dispose: function() {
		if(this.devicesDispose){this.devicesDispose();this.devicesDispose=null;}
		if(this.resourcesDispose){this.resourcesDispose();this.resourcesDispose=null;}
		clearTimeout(this.refreshTimer);
		this.refreshTimer = null;
		if (this.liveChart) {
			this.liveChart.dispose();
			this.liveChart = null;
		}
	},

	startPolling: function() {
		var self = this;
		function refresh() {
			var connected = document.documentElement.contains(self.root);
			if (connected)
				self.wasConnected = true;
			else if (self.wasConnected) {
				self.dispose();
				return;
			}

			var started = Date.now();
			L.resolveDefault(fs.read(STATUS_FILE), '{}').then(function(raw) {
				self.update(raw);
			}).finally(function() {
				if (self.root && (!self.wasConnected || document.documentElement.contains(self.root)))
					self.refreshTimer = setTimeout(refresh, Math.max(100, REFRESH_MS - (Date.now() - started)));
			});
		}

		this.refreshTimer = setTimeout(refresh, REFRESH_MS);
	},

	render: function(raw) {
		if (this.root && document.documentElement.contains(this.root)) return null;
		this.dispose();
		this.rateTimes = [];
		this.dlHistory = [];
		this.ulHistory = [];
		this.lastTimestamp = 0;
		this.wasConnected = false;
		this.root = this.build(Array.isArray(raw) ? (raw[2] || '')+'\n'+(raw[3] || '') : '');
		this.devicesDispose = Devices.mount(this.root);
		this.resourcesDispose = Resources.mount(this.root);

		if (Array.isArray(raw))
			this.loadHistory(raw[1]);
		this.liveChart = F50LiveChart.mount(this.root);
		this.update(Array.isArray(raw) ? raw[0] : raw);
		this.startPolling();
		return this.root;
	}
});
