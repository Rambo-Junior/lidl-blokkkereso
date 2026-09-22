"use strict";

const NATIVE_HOST = "hu.lidl.blokkkereso";

browser.runtime.onMessage.addListener(async (message) => {
  if (!message || message.source !== "lidl-blokkkereso-v3-content") {
    return undefined;
  }
  try {
    const response = await browser.runtime.sendNativeMessage(NATIVE_HOST, message.payload);
    return { ok: true, native: response };
  } catch (error) {
    return { ok: false, error: String(error) };
  }
});
