RSpec.describe 'Packaged formatter' do
  context 'installed gem validation' do
    it 'reports through the installed artifact' do
      expect(2 + 2).to eq(4)
    end
  end
end
