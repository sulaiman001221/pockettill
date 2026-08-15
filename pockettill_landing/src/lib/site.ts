export const siteConfig = {
  name: "PocketTill",
  title: "PocketTill — POS App for South African Spaza Shops",
  description:
    "Free POS app for spaza shops. Manage stock, track sales, run credit — works offline. Built for South African informal retailers.",
  url: "https://pockettill.co.za",
  playStoreUrl:
    "https://play.google.com/store/apps/details?id=co.pockettill.app",
  whatsappNumber: "27625631968",
  whatsappUrl:
    "https://wa.me/27625631968?text=I%20want%20to%20be%20notified%20about%20the%20PocketTill%20terminal",
  email: "hello@pockettill.co.za",
  keywords: [
    "spaza shop app",
    "spaza shop pos",
    "pos app south africa",
    "offline pos app",
    "spaza shop software",
  ],
};

export function waLink(message: string) {
  return `https://wa.me/${siteConfig.whatsappNumber}?text=${encodeURIComponent(message)}`;
}
