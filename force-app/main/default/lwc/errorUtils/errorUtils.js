/**
 * Utility module for reducing server/client errors into a list of messages.
 * Exported as a Lightning Web Component module (c/errorUtils) so it can be
 * imported from other components: import { reduceErrors } from 'c/errorUtils';
 */
export function reduceErrors(err) {
  const messages = [];

  if (!err) {
    return messages;
  }

  // If array, flatten
  if (Array.isArray(err)) {
    err.forEach((e) => {
      reduceErrors(e).forEach((m) => messages.push(m));
    });
    return Array.from(new Set(messages));
  }

  // Strings
  if (typeof err === "string") {
    messages.push(err);
    return messages;
  }

  // Native Error
  if (err instanceof Error) {
    messages.push(err.message);
    return messages;
  }

  // Common lightning/apex shapes
  try {
    // If error.body is a string try to parse it
    let body = err.body;
    if (body && typeof body === "string") {
      try {
        body = JSON.parse(body);
      } catch {
        // keep as string
      }
    }

    // Check for top-level body.message
    if (body && body.message) {
      messages.push(body.message);
    }

    // fieldErrors - map of field -> array of errors
    if (body && body.fieldErrors) {
      Object.keys(body.fieldErrors).forEach((field) => {
        const arr = body.fieldErrors[field];
        if (Array.isArray(arr)) {
          arr.forEach((fe) => {
            if (fe && fe.message) messages.push(fe.message);
          });
        }
      });
    }

    // pageErrors
    if (body && Array.isArray(body.pageErrors)) {
      body.pageErrors.forEach((pe) => {
        if (pe && pe.message) messages.push(pe.message);
      });
    }

    // Some wrappers put errors under body.output
    if (body && body.output) {
      const out = body.output;
      if (Array.isArray(out.errors)) {
        out.errors.forEach((o) => {
          if (o && o.message) messages.push(o.message);
        });
      }
      if (Array.isArray(out.pageErrors)) {
        out.pageErrors.forEach((o) => {
          if (o && o.message) messages.push(o.message);
        });
      }
    }

    // If no body shape matched, try err.message
    if (err.message) {
      messages.push(err.message);
    }

    // Last resort: stringify useful parts
    if (messages.length === 0) {
      try {
        messages.push(JSON.stringify(err));
      } catch {
        messages.push(String(err));
      }
    }
  } catch {
    // Fallback
    try {
      messages.push(JSON.stringify(err));
    } catch {
      messages.push(String(err));
    }
  }

  // Deduplicate and return
  return Array.from(new Set(messages));
}
