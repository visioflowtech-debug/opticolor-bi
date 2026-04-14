import re
import os

input_file = r'c:\opticolor\BD\respaldo_optilux_utf8.sql'
output_file = r'c:\opticolor\BD\setup_opticolor_dw.sql'

keywords_to_remove = [
    'Zoho', 'Etl_Zoho',
    'GHL', 'Etl_GHL', 'Marketing_Citas'
]

# Case-insensitive regex for keywords
keyword_pattern = re.compile('|'.join(re.escape(k) for k in keywords_to_remove), re.IGNORECASE)

def should_keep_block(block_text):
    # Skip blocks with removal keywords
    if keyword_pattern.search(block_text):
        return False
    
    # Skip CREATE/ALTER DATABASE blocks (Azure SQL compatibility)
    if re.search(r'\b(CREATE|ALTER)\s+DATABASE\b', block_text, re.IGNORECASE):
        return False
            
    return True

def process_sql():
    if not os.path.exists(input_file):
        print(f"Error: {input_file} not found")
        return

    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Split by GO (handling case and whitespace)
    raw_blocks = re.split(r'(?i)\n\s*GO\s*\n', content)
    
    cleaned_blocks = []
    removed_count = 0
    kept_count = 0
    
    for block in raw_blocks:
        block = block.strip()
        if not block:
            continue
            
        if should_keep_block(block):
            # Rename database references
            block = block.replace('db-optilux-dw', 'db-opticolor-dw')
            cleaned_blocks.append(block)
            kept_count += 1
        else:
            removed_count += 1

    # Join with GO and newline
    if cleaned_blocks:
        final_content = '\nGO\n'.join(cleaned_blocks) + '\nGO\n'
    else:
        final_content = ""

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(final_content)

    print(f"Summary:")
    print(f"Objects/Blocks Kept: {kept_count}")
    print(f"Objects/Blocks Removed: {removed_count}")
    print(f"Output saved to: {output_file}")

if __name__ == "__main__":
    process_sql()
