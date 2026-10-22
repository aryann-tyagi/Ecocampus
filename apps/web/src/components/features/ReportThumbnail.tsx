'use client';

import React, { useState, useEffect } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Image as ImageIcon, Camera } from 'lucide-react';

interface ReportThumbnailProps {
  storagePath?: string | null;
  title: string;
  className?: string;
}

// Module-level cache for signed URLs to prevent refetching during re-renders
const signedUrlCache = new Map<string, { url: string; expires: number }>();

export function ReportThumbnail({ storagePath, title, className = 'w-11 h-11' }: ReportThumbnailProps) {
  const [imgUrl, setImgUrl] = useState<string | null>(null);
  const [hasError, setHasError] = useState(false);
  const supabase = createClient();

  useEffect(() => {
    if (!storagePath) {
      setImgUrl(null);
      return;
    }

    // Check in-memory cache first (valid for 50 minutes)
    const cached = signedUrlCache.get(storagePath);
    const now = Date.now();
    if (cached && cached.expires > now) {
      setImgUrl(cached.url);
      return;
    }

    let isMounted = true;
    async function fetchUrl() {
      try {
        const { data, error } = await supabase.storage
          .from('report-photos')
          .createSignedUrl(storagePath!, 3600);

        if (!isMounted) return;

        if (error || !data?.signedUrl) {
          // Try public URL as fallback
          const { data: pubData } = supabase.storage
            .from('report-photos')
            .getPublicUrl(storagePath!);

          if (pubData?.publicUrl) {
            setImgUrl(pubData.publicUrl);
            signedUrlCache.set(storagePath!, { url: pubData.publicUrl, expires: now + 3000 * 1000 });
          } else {
            setHasError(true);
          }
          return;
        }

        setImgUrl(data.signedUrl);
        signedUrlCache.set(storagePath!, { url: data.signedUrl, expires: now + 3000 * 1000 });
      } catch {
        if (isMounted) setHasError(true);
      }
    }

    fetchUrl();

    return () => {
      isMounted = false;
    };
  }, [storagePath, supabase]);

  if (storagePath && imgUrl && !hasError) {
    return (
      <div className={`relative shrink-0 rounded-xl overflow-hidden border border-slate-200/90 shadow-2xs bg-slate-100 ${className}`}>
        <img
          src={imgUrl}
          alt={title}
          className="w-full h-full object-cover"
          onError={() => setHasError(true)}
          loading="lazy"
        />
      </div>
    );
  }

  return (
    <div
      className={`shrink-0 rounded-xl bg-slate-100 border border-slate-200/90 flex items-center justify-center text-slate-400 ${className}`}
      title={storagePath ? 'Photo attached' : 'No photo provided'}
    >
      {storagePath ? (
        <Camera className="w-4 h-4 text-emerald-700/70" />
      ) : (
        <ImageIcon className="w-4 h-4 text-slate-300" />
      )}
    </div>
  );
}
