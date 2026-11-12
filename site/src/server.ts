import handler, { createServerEntry } from "@tanstack/react-start/server-entry";

const APEX = "cliptap.app";

export default createServerEntry({
  fetch(request, opts) {
    const url = new URL(request.url);
    if (url.hostname === `www.${APEX}`) {
      url.hostname = APEX;
      url.protocol = "https:";
      return Response.redirect(url.toString(), 301);
    }
    return handler.fetch(request, opts);
  },
});
