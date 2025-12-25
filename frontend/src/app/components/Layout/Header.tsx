import React from 'react';
// lucide-react: Icon library for clean, simple SVG icons
import { Moon, Sun, Menu, User, LogOut, Settings } from 'lucide-react';
// next-themes: Manages light/dark theme preference across the app
import { useTheme } from 'next-themes';
// Our custom auth context (provides user info and sign-out function)
import { useAuth } from '../../../contexts/AuthContext';
// Reusable button component from our UI library (built on Radix + Tailwind)
import { Button } from '../ui/button';
// Avatar components (Radix headless) - displays user profile picture or initials
import { Avatar, AvatarFallback } from '../ui/avatar';
// Dropdown menu components (Radix headless) - the behavior logic without styling
// We apply Tailwind for the actual styling and positioning
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '../ui/dropdown-menu';

/**
 * HeaderProps: Configuration for the Header component
 * - onMenuClick: Callback when mobile hamburger menu is clicked
 * - showMenuButton: Whether to display the menu button (hidden on desktop)
 */
interface HeaderProps {
  onMenuClick?: () => void;
  showMenuButton?: boolean;
}

export function Header({ onMenuClick, showMenuButton = true }: HeaderProps) {
  // useTheme() comes from next-themes - it knows the current theme ('dark' or 'light')
  // setTheme() lets us update the theme (which persists to localStorage)
  const { theme, setTheme } = useTheme();
  
  // useAuth() comes from our AuthContext - provides signed-in user info and signOut function
  // 'user' will be null if no one is logged in
  const { user, signOut } = useAuth();

  /**
   * toggleTheme: Switch between light and dark mode
   * Why: We store theme preference in localStorage via next-themes library
   * This is a simple toggle - if dark, go light. If light, go dark.
   */
  const toggleTheme = () => {
    setTheme(theme === 'dark' ? 'light' : 'dark');
  };

  /**
   * getInitials: Extract user initials from their full name
   * Example: "John Smith" → "JS"
   * 
   * Why this exists: User avatars display initials if no profile image available
   * How it works:
   *  1. Split name by spaces → ["John", "Smith"]
   *  2. Map each word to its first letter → ["J", "S"]
   *  3. Join them together → "JS"
   *  4. Take only first 2 characters (in case someone has many names)
   */
  const getInitials = (name: string) => {
    return name
      .split(' ')
      .map(n => n[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);
  };

  return (
    // Main header bar: sticky (stays at top when scrolling), semi-transparent, with border
    // Tailwind classes explained:
    // - sticky top-0: Sticks to top of viewport
    // - z-50: High stacking order (appears above other content)
    // - w-full: Takes full width
    // - border-b: Border on bottom edge
    // - bg-background/95: 95% opacity of background color (semi-transparent)
    // - backdrop-blur: Blurs content behind it (modern frosted glass effect)
    <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      {/* Container: Max width + padding, flex layout to spread items horizontally */}
      <div className="container flex h-14 max-w-screen-2xl items-center px-4">
        
        {/* LEFT SECTION: Logo + Brand */}
        <div className="flex items-center gap-2">
          {/* MOBILE MENU BUTTON: Only shows on small screens (md:hidden = hidden on medium screens and up) */}
          {showMenuButton && (
            <Button
              variant="ghost"
              size="icon"
              className="md:hidden"  // Tailwind: "hidden" on medium (768px) and larger screens
              onClick={onMenuClick}
              aria-label="Toggle menu"
            >
              <Menu className="h-5 w-5" />
            </Button>
          )}
          
          {/* LOGO: Colored square with "N" letter */}
          <div className="flex items-center gap-2">
            <div className="h-8 w-8 rounded-lg bg-primary flex items-center justify-center">
              {/* bg-primary: Uses the primary brand color from our theme */}
              <span className="text-primary-foreground text-sm">N</span>
            </div>
            {/* APP NAME: Only shows on small devices and up (hidden:sm = visible starting at sm) */}
            <h1 className="text-lg hidden sm:block">Notes</h1>
          </div>
        </div>

        {/* RIGHT SECTION: Theme toggle + User menu */}
        {/* flex-1: Takes remaining space, pushing items to the right */}
        <div className="flex flex-1 items-center justify-end gap-2">
          
          {/* THEME TOGGLE BUTTON: Sun/Moon icon, changes on click */}
          <Button
            variant="ghost"
            size="icon"
            onClick={toggleTheme}
            aria-label="Toggle theme"
          >
            {/* Conditional rendering: Show sun icon in dark mode, moon icon in light mode */}
            {theme === 'dark' ? (
              <Sun className="h-5 w-5" />
            ) : (
              <Moon className="h-5 w-5" />
            )}
          </Button>

          {/* USER DROPDOWN MENU: Only shows if user is logged in */}
          {user && (
            // DropdownMenu: Radix UI headless component for menu behavior (accessibility, keyboard nav, etc)
            // We provide styling via Tailwind classes on the child components
            <DropdownMenu>
              {/* DropdownMenuTrigger: The button that opens the menu when clicked */}
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" className="relative h-9 w-9 rounded-full">
                  {/* Avatar: Radix-based component showing user profile picture or fallback initials */}
                  <Avatar className="h-9 w-9">
                    {/* AvatarFallback: Shown if no image available (displays initials we calculated) */}
                    <AvatarFallback>{getInitials(user.name)}</AvatarFallback>
                  </Avatar>
                </Button>
              </DropdownMenuTrigger>
              
              {/* DropdownMenuContent: The actual dropdown panel that appears below the trigger */}
              {/* w-56: Width of 224px, align="end": Aligns right edge with trigger button */}
              <DropdownMenuContent className="w-56" align="end">
                
                {/* USER INFO HEADER: Shows name and email in the dropdown */}
                <DropdownMenuLabel>
                  <div className="flex flex-col space-y-1">
                    <p className="text-sm leading-none">{user.name}</p>
                    <p className="text-xs leading-none text-muted-foreground">
                      {user.email}
                    </p>
                  </div>
                </DropdownMenuLabel>
                
                {/* Visual separator line between sections */}
                <DropdownMenuSeparator />
                
                {/* PROFILE MENU ITEM: Links to profile page */}
                <DropdownMenuItem asChild>
                  <a href="/profile" className="cursor-pointer">
                    <User className="mr-2 h-4 w-4" />
                    Profile
                  </a>
                </DropdownMenuItem>
                
                {/* SETTINGS MENU ITEM: Links to settings page */}
                <DropdownMenuItem asChild>
                  <a href="/settings" className="cursor-pointer">
                    <Settings className="mr-2 h-4 w-4" />
                    Settings
                  </a>
                </DropdownMenuItem>
                
                {/* Another separator before sign out */}
                <DropdownMenuSeparator />
                
                {/* SIGN OUT MENU ITEM: Calls signOut() function from AuthContext */}
                {/* text-destructive: Red color to indicate this is a destructive action */}
                <DropdownMenuItem onClick={signOut} className="cursor-pointer text-destructive">
                  <LogOut className="mr-2 h-4 w-4" />
                  Sign out
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          )}
        </div>
      </div>
    </header>
  );
}
