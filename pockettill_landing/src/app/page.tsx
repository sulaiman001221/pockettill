import Navbar from "@/components/Navbar";
import Hero from "@/components/Hero";
import Features from "@/components/Features";
import ComingSoon from "@/components/ComingSoon";
import WhoItsFor from "@/components/WhoItsFor";
import Footer from "@/components/Footer";

export default function Home() {
  return (
    <main>
      <Navbar />
      <Hero />
      <Features />
      <ComingSoon />
      <WhoItsFor />
      <Footer />
    </main>
  );
}
