/*
  # Create Stock Management System

  1. New Tables
    - `stocks`
      - `id` (uuid, primary key)
      - `name` (text, unique)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

    - `stock_produit`
      - `id` (uuid, primary key)
      - `produit_id` (uuid, references products)
      - `stock_id` (uuid, references stocks)
      - `quantite` (integer)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Changes to products table
    - Add stock_total column
    - Add trigger for automatic stock calculation

  3. Security
    - Enable RLS
    - Add policies for authenticated users
*/

-- Create stocks table if it doesn't exist
CREATE TABLE IF NOT EXISTS stocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create stock_produit table if it doesn't exist
CREATE TABLE IF NOT EXISTS stock_produit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  produit_id uuid REFERENCES products(id) ON DELETE CASCADE,
  stock_id uuid REFERENCES stocks(id) ON DELETE CASCADE,
  quantite integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(produit_id, stock_id)
);

-- Add stock_total column to products if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'products' AND column_name = 'stock_total'
  ) THEN
    ALTER TABLE products ADD COLUMN stock_total integer DEFAULT 0;
  END IF;
END $$;

-- Create function to update stock_total
CREATE OR REPLACE FUNCTION update_stock_total() 
RETURNS TRIGGER AS $$ 
BEGIN
  -- Calculate new total stock for the product
  UPDATE products 
  SET stock_total = (
    SELECT COALESCE(SUM(quantite), 0) 
    FROM stock_produit 
    WHERE produit_id = COALESCE(NEW.produit_id, OLD.produit_id)
  )
  WHERE id = COALESCE(NEW.produit_id, OLD.produit_id);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for stock_total updates
DROP TRIGGER IF EXISTS stock_total_update ON stock_produit;
CREATE TRIGGER stock_total_update
  AFTER INSERT OR UPDATE OR DELETE ON stock_produit
  FOR EACH ROW
  EXECUTE FUNCTION update_stock_total();

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_stock_produit_produit_id ON stock_produit(produit_id);
CREATE INDEX IF NOT EXISTS idx_stock_produit_stock_id ON stock_produit(stock_id);

-- Enable RLS
ALTER TABLE stocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_produit ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
DO $$ 
BEGIN
  -- Drop existing policies if they exist
  DROP POLICY IF EXISTS "Enable read access for authenticated users" ON stocks;
  DROP POLICY IF EXISTS "Enable write access for authenticated users" ON stocks;
  DROP POLICY IF EXISTS "Enable read access for authenticated users" ON stock_produit;
  DROP POLICY IF EXISTS "Enable write access for authenticated users" ON stock_produit;

  -- Create new policies
  CREATE POLICY "Enable read access for authenticated users"
    ON stocks
    FOR SELECT
    TO authenticated
    USING (true);

  CREATE POLICY "Enable write access for authenticated users"
    ON stocks
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

  CREATE POLICY "Enable read access for authenticated users"
    ON stock_produit
    FOR SELECT
    TO authenticated
    USING (true);

  CREATE POLICY "Enable write access for authenticated users"
    ON stock_produit
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);
END $$;

-- Create updated_at function if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS update_stocks_updated_at ON stocks;
DROP TRIGGER IF EXISTS update_stock_produit_updated_at ON stock_produit;

-- Create updated_at triggers
CREATE TRIGGER update_stocks_updated_at
  BEFORE UPDATE ON stocks
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_stock_produit_updated_at
  BEFORE UPDATE ON stock_produit
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert initial stocks
INSERT INTO stocks (name) VALUES
  ('Stock Principal'),
  ('Stock Secondaire'),
  ('SAV')
ON CONFLICT (name) DO NOTHING;