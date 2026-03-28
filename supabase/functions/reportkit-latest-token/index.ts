function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
    },
  });
}

Deno.serve((_req) => {
  return json({
    ok: false,
    error: "deprecated",
    message: "reportkit-latest-token is removed. Use authenticated token registration and reportkit-send-live-activity.",
  }, 410);
});
