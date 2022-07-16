const { join } = require('path');
const polka = require('polka');

const dir = join(__dirname, './');
const serve = require('serve-static')(dir);

polka()
	.use(serve)
	.listen(3002, () => {
		console.log(`> Running on http://localhost:3002`);
	});

// http://127.0.0.1:3002/index.html
