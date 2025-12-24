import React from 'react';
import { Home, FileText, Tag, Settings, X } from 'lucide-react';
import { Button } from '../ui/button';
import { ScrollArea } from '../ui/scroll-area';
import { Separator } from '../ui/separator';
import { Badge } from '../ui/badge';
import { useTags } from '../../../hooks/useNotes';

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
  selectedTag?: string;
  onTagSelect?: (tag: string) => void;
}

export function Sidebar({ isOpen, onClose, selectedTag, onTagSelect }: SidebarProps) {
  const { data: tags = [] } = useTags();

  const navItems = [
    { icon: Home, label: 'All Notes', href: '/notes' },
    { icon: FileText, label: 'Recent', href: '/notes?sort=recent' },
    { icon: Tag, label: 'Tags', href: '#tags' },
    { icon: Settings, label: 'Settings', href: '/settings' },
  ];

  return (
    <>
      {/* Mobile backdrop */}
      {isOpen && (
        <div
          className="fixed inset-0 z-40 bg-background/80 backdrop-blur-sm md:hidden"
          onClick={onClose}
        />
      )}

      {/* Sidebar */}
      <aside
        className={`
          fixed top-14 left-0 z-40 h-[calc(100vh-3.5rem)] w-64 border-r bg-background transition-transform duration-200 md:translate-x-0
          ${isOpen ? 'translate-x-0' : '-translate-x-full'}
        `}
      >
        <div className="flex h-full flex-col">
          {/* Close button for mobile */}
          <div className="flex items-center justify-between p-4 md:hidden">
            <h2 className="text-lg">Menu</h2>
            <Button
              variant="ghost"
              size="icon"
              onClick={onClose}
              aria-label="Close menu"
            >
              <X className="h-5 w-5" />
            </Button>
          </div>

          <ScrollArea className="flex-1 px-3">
            <div className="space-y-1 py-4">
              {navItems.map((item) => {
                const Icon = item.icon;
                return (
                  <a
                    key={item.href}
                    href={item.href}
                    className="flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors hover:bg-accent hover:text-accent-foreground"
                  >
                    <Icon className="h-4 w-4" />
                    {item.label}
                  </a>
                );
              })}
            </div>

            <Separator className="my-4" />

            <div className="pb-4">
              <h3 className="mb-2 px-3 text-xs text-muted-foreground uppercase tracking-wider">
                Tags
              </h3>
              <div className="space-y-1">
                {tags.length === 0 ? (
                  <p className="px-3 py-2 text-xs text-muted-foreground">
                    No tags yet
                  </p>
                ) : (
                  tags.map((tag) => (
                    <button
                      key={tag}
                      onClick={() => onTagSelect?.(tag)}
                      className={`
                        flex w-full items-center justify-between rounded-lg px-3 py-2 text-sm transition-colors hover:bg-accent hover:text-accent-foreground
                        ${selectedTag === tag ? 'bg-accent' : ''}
                      `}
                    >
                      <span className="truncate">{tag}</span>
                      <Badge variant="secondary" className="ml-2 text-xs">
                        {/* This would show count in real app */}
                      </Badge>
                    </button>
                  ))
                )}
              </div>
            </div>
          </ScrollArea>

          <div className="border-t p-4">
            <p className="text-xs text-muted-foreground text-center">
              Version 1.0.0
            </p>
          </div>
        </div>
      </aside>
    </>
  );
}
