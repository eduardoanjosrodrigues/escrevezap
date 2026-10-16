module Meta
  class Service
    GRAPH_URL       = "https://graph.facebook.com/v25.0/".freeze
    PHONE_NUMBER_ID = "1010460445488841".freeze
    WABA_ID         = "950814390965540".freeze

    # O token fica só nas credentials (meta.token); nunca no código.
    def self.token
      Rails.application.credentials.dig(:meta, :token).presence ||
        raise(KeyError, "credentials meta.token não configurado")
    end

    # Código 131056: mandamos mensagens demais para o mesmo número num curto
    # intervalo. Não é falha definitiva — basta esperar e reenviar.
    PAIR_RATE_LIMIT_CODE = "131056".freeze

    def self.pair_rate_limited?(error)
      error.is_a?(ApiRequest::ApiClientError) && error.message.include?(PAIR_RATE_LIMIT_CODE)
    end

    def initialize(recipient:, sender: PHONE_NUMBER_ID, meta_waba_id: WABA_ID)
      @recipient = recipient
      @sender = sender
      @meta_waba_id = meta_waba_id

      load_api_request_instance
    end

    def send_template(template_json, rendered_message: nil)
      payload = {
        messaging_product: "whatsapp",
        to: @recipient,
        type: "template",
        template: template_json
      }

      response = @api_request.post("/messages", payload)
      track_outgoing_message(message_type: :template, body: rendered_message.presence || "Template enviado", metadata: payload, response: response)
    end

    # Marca a mensagem recebida como lida e mostra "digitando…" para o usuário
    # até a nossa próxima mensagem (a Meta encerra sozinha após ~25 s).
    def mark_read_with_typing(message_id)
      @api_request.post("/messages", {
        messaging_product: "whatsapp",
        status: "read",
        message_id: message_id,
        typing_indicator: { type: "text" }
      })
    end

    def send_message(text)
      payload = {
        messaging_product: "whatsapp",
        to: @recipient,
        type: "text",
        text: { body: text }
      }

      response = @api_request.post("/messages", payload)
      track_outgoing_message(message_type: :text, body: text, metadata: payload, response: response)
    end

    # Exemplo de Uso:
    # Chip.meta.last.meta_service('5521936181803').send_message_with_buttons("Escolha uma opção:", ["Opção 1", "Opção 2", "Opção 3"])
    def send_message_with_buttons(text, buttons)
      payload = {
        messaging_product: "whatsapp",
        to: @recipient,
        type: "interactive",
        interactive: {
          type: "button",
          body: { text: text },
          action: {
            buttons: buttons.map.with_index do |button, index|
              if button.is_a?(String)
                {
                  type: "reply",
                  reply: {
                    id: "button_#{index + 1}",
                    title: button.slice(0, 20)
                  }
                }
              else
                button
              end
            end
          }
        }
      }

      response = @api_request.post("/messages", payload)
      track_outgoing_message(message_type: :interactive, body: text, metadata: payload, response: response)
    end

    # Chip.meta.last.meta_service('5521936181803').send_image_with_buttons("Escolha uma opção:", ImageRestoration.last.restored_image.blob.url, ["Quero comprar", "Mandar outra", "Não gostei"])
    def send_image_with_buttons(text, media_id, buttons)
      payload = {
        messaging_product: "whatsapp",
        to: @recipient,
        type: "interactive",
        interactive: {
          type: "button",
          header: {
            type: "image",
            image: {
              id: media_id # must be a public URL or uploaded media id
            }
          },
          body: {
            text: text
          },
          action: {
            buttons: buttons.map.with_index do |button, index|
              # Se o button for string, transforma em botão reply
              if button.is_a?(String)
                {
                  type: "reply",
                  reply: {
                    id: "button_#{index + 1}",
                    title: button.slice(0, 20)
                  }
                }
              else
                button
              end
            end
          }
        }
      }

      response = @api_request.post("/messages", payload)
      track_outgoing_message(message_type: :interactive, body: text, metadata: payload, response: response)
    end

    # Envia uma mensagem interativa do tipo List no WhatsApp
    def send_list_message(body_text:, button_text:, sections:, header_text: nil, footer_text: nil)
      interactive = {
        type: "list",
        body: { text: body_text },
        action: {
          button: button_text,
          sections: sections.map do |sec|
            {
              title: sec[:title],
              rows: sec[:rows].map do |row|
                {
                  id: row[:id],
                  title: row[:title].slice(0, 24), # Limite de 24 caracteres da API do WhatsApp
                  description: row[:description]&.slice(0, 72) # Limite de 72 caracteres
                }.compact
              end
            }
          end
        }
      }

      interactive[:header] = { type: "text", text: header_text.slice(0, 60) } if header_text.present?
      interactive[:footer] = { text: footer_text.slice(0, 60) } if footer_text.present?

      payload = {
        messaging_product: "whatsapp",
        to: @recipient,
        type: "interactive",
        interactive: interactive
      }

      response = @api_request.post("/messages", payload)
      track_outgoing_message(message_type: :interactive, body: body_text, metadata: payload, response: response)
    end

    # Envia uma mensagem interativa do tipo cta_url (link) no WhatsApp
    def send_cta_url_message(body_text:, button_text:, url:, header_text: nil, footer_text: nil)
      interactive = {
        type: "cta_url",
        body: { text: body_text },
        action: {
          name: "cta_url",
          parameters: {
            display_text: button_text.slice(0, 20),
            url: url
          }
        }
      }

      interactive[:header] = { type: "text", text: header_text.slice(0, 60) } if header_text.present?
      interactive[:footer] = { text: footer_text.slice(0, 60) } if footer_text.present?

      payload = {
        messaging_product: "whatsapp",
        to: @recipient,
        type: "interactive",
        interactive: interactive
      }

      response = @api_request.post("/messages", payload)
      track_outgoing_message(message_type: :interactive, body: body_text, metadata: payload, response: response)
    end

    def send_contact(name:, phone:)
      payload = {
        messaging_product: "whatsapp",
        to: @recipient,
        type: "contacts",
        contacts: get_waha_contact(name: name, phone_number: phone)
      }

      response = @api_request.post("/messages", payload)
      track_outgoing_message(message_type: :contact, body: "Contato enviado", metadata: payload, response: response)
    end

    # Envia um contato do WhatsApp
    # def send_contact(name:, phone:)
    #   first_name, *last_name_parts = name.split(" ")
    #   last_name = last_name_parts.join(" ")

    #   contact = {
    #     name: {
    #       formatted_name: name,
    #       first_name: first_name
    #     },
    #     phones: [
    #       {
    #         phone: phone,
    #         type: "WORK",
    #         wa_id: phone
    #       }
    #     ]
    #   }

    #   contact[:name][:last_name] = last_name if last_name.present?

    #   @api_request.post("/messages", {
    #     messaging_product: "whatsapp",
    #     to: @recipient,
    #     type: "contacts",
    #     contacts: [ contact ]
    #   })
    # end

    def send_pix_code(
      reference_id:, pix_code:, total_amount_cents:, description:
    )
      payload = {
        messaging_product: "whatsapp",
        "recipient_type": "individual",
        "to": @recipient,
        "type": "interactive",
        "interactive": {
          "type": "order_details",
          "body": {
            "text": "Pagamento do Plano Escolhido" # "Plano de Restauração Diamante"
          },
          "action": {
            "name": "review_and_pay",
            "parameters": {
              "reference_id": reference_id,
              "type": "digital-goods",
              "payment_type": "br",
              "payment_settings": [
                {
                  "type": "pix_dynamic_code",
                  "pix_dynamic_code": {
                    "code": pix_code,
                    "merchant_name": "EscreveZap".slice(0, 56),
                    "key": Rails.application.credentials.dig(:inter, :pix_key),
                    "key_type": "EVP" # Eh uma key aleatoria
                  }
                }
              ],
              "currency": "BRL",
              "total_amount": {
                "value": total_amount_cents,
                "offset": 100
              },
              "order": {
                "status": "pending",
                "tax": {
                  "value": 0,
                  "offset": 100,
                  "description": "optional text"
                  },
                "items": [
                  {
                    "retailer_id": "1234567",
                    "name": description,
                    "amount": {
                      "value": total_amount_cents,
                      "offset": 100
                    },
                    "quantity": 1
                  }
                ],
                "subtotal": {
                  "value": total_amount_cents,
                  "offset": 100
                }
              }
            }
          }
        }
      }

      response = @api_request.post("/messages", payload)
      track_outgoing_message(message_type: :interactive, body: "Pagamento do Plano Escolhido", metadata: payload, response: response)
    end

    private

    def track_outgoing_message(message_type:, body:, metadata: {}, response: nil)
      phone = @recipient.to_s.gsub(/\D/, "")
      return if phone.blank?

      user = resolve_user_for_phone(phone)
      sender = @sender.to_s

      WhatsappMessage.create!(
        user: user,
        phone: phone,
        from: sender,
        to: "#{phone}@c.us",
        message_id: extract_message_id(response),
        direction: :outgoing,
        message_type: message_type,
        body: body.presence || "(sem texto)",
        metadata: {
          source: "meta_service"
        }.merge(metadata || {}),
        sent_at: Time.current
      )
    rescue => e
      Rails.logger.error "[Meta::Service#track_outgoing_message] Error: #{e.class} #{e.message}"
      Sentry.capture_exception(e)
    end

    def extract_message_id(response)
      return nil unless response.is_a?(Hash)

      response.dig("messages", 0, "id")
    end

    def resolve_user_for_phone(phone)
      candidates = [
        phone,
        "+#{phone}",
        phone.sub(/^55/, ""),
        "+#{phone.sub(/^55/, "")}",
      ].compact.uniq

      user = User.find_by(uid: candidates)
      return user if user

      session = WahaSession.find_by(waha_chat_id: "#{phone}@c.us")
      session&.user
    end

    def send_image(media_id, filename, caption)
      @api_request.post("/messages", {
        messaging_product: "whatsapp",
        to: @recipient,
        type: "image",
        image: { id: media_id, caption: caption }
      })
    end

    def upload_media(blob)
      # Returns Meta MEDIA ID
      response = @api_request.post_form_data(
        "/media",
        form_data: {
          messaging_product: "whatsapp"
        },
        file_path: blob.service.send(:path_for, blob.key),
        file_content_type: blob.content_type
      )

      response["id"]
    end

    def self.download_media(media_id, meta_waba_id)
      api_request = ApiRequest.new(GRAPH_URL, {
        "Authorization" => "Bearer #{token}"
      })

      response = api_request.get("/#{media_id}")

      api_request = ApiRequest.new(response["url"], {
        "Authorization" => "Bearer #{token}",
        "Accept" => response["mime_type"]
      })
      api_request.get("", {}, { "Accept" => response["mime_type"] })
    end

    def get_all_available_templates
      @api_request = ApiRequest.new("#{GRAPH_URL}#{@meta_waba_id}", {
        "Authorization" => "Bearer #{self.class.token}"
      })
      response = @api_request.get("/message_templates?language=pt_BR&status=approved")
      response["data"]
    end

    private

    def get_waha_contact(name:, phone_number:)
      [ {
        name: {
          formatted_name: name,
          first_name: name.split(" ").first,
          last_name: name.split(" ").last
        },
        org: {
          company: "EscreveZap",
          department: "Suporte",
          title: "Atendimento"
        },
        phones: [
          {
            phone: phone_number,
            type: "work",
            wa_id: "55#{phone_number}"
          }
        ]
      } ]
    end

    def load_api_request_instance
      @api_request = ApiRequest.new("#{GRAPH_URL}#{@sender}", {
        "Authorization" => "Bearer #{self.class.token}"
      })
    end
  end
end
