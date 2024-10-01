class CreateProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :products do |t|
      t.string :url
      t.string :name
      t.decimal :price, precision: 10, scale: 2
      t.string :image_url

      t.timestamps
    end
  end
end
