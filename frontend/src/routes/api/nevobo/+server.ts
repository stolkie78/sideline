import type { RequestHandler } from './$types';

const NEVOBO_API = 'https://api.nevobo.nl';

export const GET: RequestHandler = async ({ url }) => {
	const path = url.searchParams.get('path');
	if (!path) {
		return new Response(JSON.stringify({ error: 'Missing path parameter' }), {
			status: 400,
			headers: { 'Content-Type': 'application/json' }
		});
	}

	try {
		const res = await fetch(`${NEVOBO_API}${path}`, {
			headers: { Accept: 'application/json' }
		});
		const data = await res.json();
		return new Response(JSON.stringify(data), {
			status: res.status,
			headers: { 'Content-Type': 'application/json' }
		});
	} catch (e) {
		return new Response(JSON.stringify({ error: String(e) }), {
			status: 500,
			headers: { 'Content-Type': 'application/json' }
		});
	}
};
