class ProductsController < ApplicationController
  require 'nokogiri'
  require 'open-uri'

  def new; end

  def index
    @query = params[:query]
    @products = []
    # binding.pry
    if @query.present?
      if !!valid_ozby_url?(@query)
        product = Product.find_by(url: @query)
        if product
          @products << product
        else
          @error = 'Товар не найден в базе данных'
        end
      else
        @products = Product.where('name LIKE ?', "%#{@query}%")
        @error = 'Товары не найдены' if @products.empty?
      end
    end

    # Считаем среднюю цену по дням за текущий месяц
    @price_data = calculate_price_data(@products)
  end

  def create
    @errors = []
    urls = params[:urls].split("\n").map(&:strip)

    urls.each do |url|
      if valid_ozby_url?(url)
        product_info = fetch_product_data(url)
        if product_info
          product = Product.find_or_create_by(url:, name: product_info[:name], image_url: product_info[:image_url])
          create_price_history(product, product_info[:price])

        else
          @errors << "Не удалось получить данные для #{url}"
        end
      else
        @errors << "Неправильный URL: #{url}"
      end
    end

    if @errors.empty?
      redirect_to products_path, notice: 'Товары успешно добавлены'
    else
      render :new
    end
  end

  private

  # Проверяем, является ли запрос ссылкой на OZ.BY
  def valid_ozby_url?(url)
    url =~ %r{\Ahttps?://(www\.)?oz\.by/.+}
  end

  # Рассчитываем среднюю цену по дням для текущего месяца
  def calculate_price_data(products)
    price_data = {}
    current_month = Time.zone.now.month
    current_year = Time.zone.now.year

    products.each do |product|
      price_data[product.id] = {}

      # Получаем цены за текущий месяц
      (1..Time.days_in_month(current_month)).each do |day|
        day_prices = product.price_histories.where(
          created_at: Time.zone.local(current_year, current_month, day).all_day
        ).pluck(:price)

        if day_prices.any?
          average_price = day_prices.sum / day_prices.size
          price_data[product.id][day] = average_price
        else
          price_data[product.id][day] = '-'
        end
      end
    end

    price_data
  end

  # Валидация ссылок на OZ.BY
  def valid_ozby_url?(url)
    url =~ %r{\Ahttps?://(www\.)?oz\.by/.+}
  end

  # Функция для парсинга страницы и получения данных о товаре
  def fetch_product_data(url)
    doc = Nokogiri::HTML(URI.open(url))
    name = doc.css('h1').text.strip
    price = doc.css('span.b-product-control__text.b-product-control__text_main').first.text.strip.split(' р.').first.gsub(
      ',', '.'
    ).to_f
    image_url = doc.css('.b-product-photo img').attr('src').value

    puts "Название: #{name}, Цена: #{price}, Ссылка на картинку: #{image_url}" # Отладка

    { name:, price:, image_url: }
  rescue StandardError => e
    puts "Ошибка парсинга: #{e.message}" # Отладка
    nil
  end

  def create_price_history(product, price)
    product_price_histories = product.price_histories.where(created_at: Date.today.all_day)
    if product_price_histories.present?
      price_histories_with_current_price = product_price_histories.where(price:)
      PriceHistory.create(product:, price:) if price_histories_with_current_price.empty?
    else
      PriceHistory.create(product:, price:)
    end
  end
end
