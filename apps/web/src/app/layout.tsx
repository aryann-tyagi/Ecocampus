import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'EcoCampus — Staff & Admin Operations',
  description: 'Campus issue management, department assignment, and lifecycle resolution dashboard for EcoCampus.',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="bg-[#F8FAF8] text-slate-900 min-h-screen antialiased">
        {children}
      </body>
    </html>
  );
}
