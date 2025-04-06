/*
  # Create Multi-Stock Management System

  1. New Tables
    - `stock_groups`
      - `id` (uuid, primary key)
      - `name` (text, unique)
      - `synchronizable` (boolean)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

    - `stocks`
      - `id` (uuid, primary key)
      - `name` (text, unique)
      - `group_id` (uuid, references stock_groups)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

    - `product_stocks`
      - `id` (uuid, primary key)
      - `product_id` (uuid, references products)
      - `stock_id` (uuid, references stocks)
      - `quantity` (integer)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Changes to products table
    - Add total_stock column
    - Add trigger for automatic stock calculation

  3. Security
    - Enable RLS
    - Add policies for authenticated users
*/

-- Create stock_groups table
CREATE TABLE stock_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  synchronizable boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create stocks table
CREATE TABLE stocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  group_id uuid REFERENCES stock_groups(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create product_stocks table
CREATE TABLE product_stocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES products(id) ON DELETE CASCADE,
  stock_id uuid REFERENCES stocks(id) ON DELETE CASCADE,
  quantity integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(product_id, stock_id)
);

-- Add total_stock to products
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS total_stock integer DEFAULT 0;

-- Create function to update total stock
CREATE OR REPLACE FUNCTION update_product_total_stock()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE products
  SET total_stock = (
    SELECT COALESCE(SUM(quantity), 0)
    FROM product_stocks
    WHERE product_id = COALESCE(NEW.product_id, OLD.product_id)
  )
  WHERE id = COALESCE(NEW.product_id, OLD.product_id);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for total stock updates
CREATE TRIGGER update_product_total_stock
AFTER INSERT OR UPDATE OR DELETE ON product_stocks
FOR EACH ROW
EXECUTE FUNCTION update_product_total_stock();

-- Enable RLS
ALTER TABLE stock_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE stocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_stocks ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Allow all access for authenticated users"
  ON stock_groups
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow all access for authenticated users"
  ON stocks
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow all access for authenticated users"
  ON product_stocks
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Insert initial stock groups
INSERT INTO stock_groups (name, synchronizable) VALUES
  ('Internet', true),
  ('SAV', false),
  ('À réparer', false)
ON CONFLICT (name) DO NOTHING;

-- Insert initial stocks
DO $$
DECLARE
  internet_id uuid;
  sav_id uuid;
  repair_id uuid;
BEGIN
  SELECT id INTO internet_id FROM stock_groups WHERE name = 'Internet';
  SELECT id INTO sav_id FROM stock_groups WHERE name = 'SAV';
  SELECT id INTO repair_id FROM stock_groups WHERE name = 'À réparer';

  INSERT INTO stocks (name, group_id) VALUES
    ('Back Market', internet_id),
    ('eBay', internet_id),
    ('SAV UA', sav_id),
    ('À réparer Toulouse', repair_id)
  ON CONFLICT (name) DO NOTHING;
END $$;