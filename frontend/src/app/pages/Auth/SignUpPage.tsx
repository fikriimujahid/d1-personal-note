import React, { useState } from 'react';
import { Loader2 } from 'lucide-react';
import { useAuth } from '../../../contexts/AuthContext';
import { Button } from '../../components/ui/button';
import { Input } from '../../components/ui/input';
import { Label } from '../../components/ui/label';
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from '../../components/ui/card';

export function SignUpPage() {
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    password: '',
    confirmPassword: '',
  });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isLoading, setIsLoading] = useState(false);
  const [needsVerification, setNeedsVerification] = useState(false);
  const [verificationCode, setVerificationCode] = useState('');
  const { signUp, confirmSignUp } = useAuth();

  const validateForm = () => {
    const newErrors: Record<string, string> = {};

    if (!formData.name.trim()) {
      newErrors.name = 'Name is required';
    }

    if (!formData.email.trim()) {
      newErrors.email = 'Email is required';
    } else if (!/\S+@\S+\.\S+/.test(formData.email)) {
      newErrors.email = 'Please enter a valid email address';
    }

    if (!formData.password) {  // pragma: allowlist secret
      newErrors.password = 'Password is required';  // pragma: allowlist secret
    } else if (formData.password.length < 8) {  // pragma: allowlist secret
      newErrors.password = 'Password must be at least 8 characters';  // pragma: allowlist secret
    }

    if (formData.password !== formData.confirmPassword) {  // pragma: allowlist secret
      newErrors.confirmPassword = 'Passwords do not match';  // pragma: allowlist secret
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!validateForm()) {
      return;
    }

    setIsLoading(true);

    try {
      await signUp({
        name: formData.name,
        email: formData.email,
        password: formData.password,
      });
      setNeedsVerification(true);
    } catch (error) {
      // Error handled by context
    } finally {
      setIsLoading(false);
    }
  };

  const handleVerification = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      await confirmSignUp(formData.email, verificationCode);
      window.history.pushState({}, '', '/signin');
      window.dispatchEvent(new PopStateEvent('popstate'));
    } catch (error) {
      // Error handled by context
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <Card className="w-full max-w-md">
        <CardHeader className="space-y-1">
          <CardTitle className="text-2xl text-center">
            {needsVerification ? 'Verify your email' : 'Create an account'}
          </CardTitle>
          <CardDescription className="text-center">
            {needsVerification
              ? 'Enter the verification code sent to your email'
              : 'Enter your information to get started'}
          </CardDescription>
        </CardHeader>
        {needsVerification ? (
          <form onSubmit={handleVerification} className="space-y-4">
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="code">Verification Code</Label>
                <Input
                  id="code"
                  placeholder="Enter 6-digit code"
                  value={verificationCode}
                  onChange={(e) => setVerificationCode(e.target.value)}
                  required
                />
              </div>
            </CardContent>
            <CardFooter className="flex flex-col space-y-4">
              <Button type="submit" className="w-full" disabled={isLoading}>
                {isLoading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Verifying...
                  </>
                ) : (
                  'Verify Email'
                )}
              </Button>
            </CardFooter>
          </form>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="name">Name</Label>
                <Input
                  id="name"
                  placeholder="John Doe"
                  value={formData.name}
                  onChange={(e) => {
                    setFormData(f => ({ ...f, name: e.target.value }));
                    if (errors.name) setErrors(e => ({ ...e, name: '' }));
                  }}
                />
                {errors.name && <p className="text-sm text-red-500">{errors.name}</p>}
              </div>
              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="john@example.com"
                  value={formData.email}
                  onChange={(e) => {
                    setFormData(f => ({ ...f, email: e.target.value }));
                    if (errors.email) setErrors(e => ({ ...e, email: '' }));
                  }}
                />
                {errors.email && <p className="text-sm text-red-500">{errors.email}</p>}
              </div>
              <div className="space-y-2">
                <Label htmlFor="password">Password</Label>
                <Input
                  id="password"
                  type="password"
                  value={formData.password}
                  onChange={(e) => {
                    setFormData(f => ({ ...f, password: e.target.value }));
                    if (errors.password) setErrors(e => ({ ...e, password: '' }));
                  }}
                />
                {errors.password && <p className="text-sm text-red-500">{errors.password}</p>}
              </div>
              <div className="space-y-2">
                <Label htmlFor="confirmPassword">Confirm Password</Label>
                <Input
                  id="confirmPassword"
                  type="password"
                  value={formData.confirmPassword}
                  onChange={(e) => {
                    setFormData(f => ({ ...f, confirmPassword: e.target.value }));
                    if (errors.confirmPassword) setErrors(e => ({ ...e, confirmPassword: '' }));
                  }}
                />
                {errors.confirmPassword && <p className="text-sm text-red-500">{errors.confirmPassword}</p>}
              </div>
            </CardContent>
            <CardFooter className="flex flex-col space-y-4">
              <Button type="submit" className="w-full" disabled={isLoading}>
                {isLoading ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Creating account...
                  </>
                ) : (
                  'Sign Up'
                )}
              </Button>
              <p className="text-sm text-center text-muted-foreground">
                Already have an account?{' '}
                <a href="/signin" className="text-primary hover:underline">
                  Sign in
                </a>
              </p>
            </CardFooter>
          </form>
        )}
      </Card>
    </div>
  );
}
