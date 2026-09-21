import { Link } from "@tanstack/react-router";
import { Github, Linkedin } from "lucide-react";
import logo from "@/assets/iyeob.png.asset.json";

export function SiteFooter() {
  return (
    <footer className="border-t border-border bg-foreground text-primary-foreground">
      <div className="mx-auto grid max-w-7xl gap-12 px-5 py-16 sm:grid-cols-2 lg:grid-cols-5 lg:px-8">
        <div className="sm:col-span-2">
          <Link to="/" className="flex items-center gap-2.5"><img src={logo.url} alt="" className="size-10 object-contain" /><span className="font-display text-xl font-extrabold">IYEOB</span></Link>
          <p className="mt-5 max-w-sm text-sm leading-6 text-primary-foreground/65">Build AI with data designed for Africa. Synthetic infrastructure for responsible research and development.</p>
          <div className="mt-6 flex gap-3"><a href="https://github.com" aria-label="GitHub" className="rounded-md border border-primary-foreground/15 p-2 hover:bg-primary-foreground/10"><Github className="size-4" /></a><a href="https://linkedin.com" aria-label="LinkedIn" className="rounded-md border border-primary-foreground/15 p-2 hover:bg-primary-foreground/10"><Linkedin className="size-4" /></a></div>
        </div>
        <FooterColumn title="Product" items={["Datasets", "APIs · Soon", "Models · Soon", "AI Evaluation · Soon"]} />
        <FooterColumn title="Resources" items={["Documentation", "Research", "Dataset guide", "API documentation"]} />
        <FooterColumn title="Company" items={["About", "Contact", "Contribute", "Privacy"]} />
      </div>
      <div className="border-t border-primary-foreground/10 px-5 py-5 text-center text-xs text-primary-foreground/50">© 2026 IYEOB. Every published record is synthetic.</div>
    </footer>
  );
}

function FooterColumn({ title, items }: { title: string; items: string[] }) {
  return <div><h3 className="text-sm font-bold">{title}</h3><ul className="mt-4 space-y-3">{items.map((item) => <li key={item} className="text-sm text-primary-foreground/60">{item}</li>)}</ul></div>;
}